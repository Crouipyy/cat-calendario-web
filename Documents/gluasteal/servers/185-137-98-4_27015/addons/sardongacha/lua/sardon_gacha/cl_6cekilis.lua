-- "addons\\sardongacha\\lua\\sardon_gacha\\cl_6cekilis.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
/*
*   Dilek animasyonu (tam ekran, TAB menüsünün üstünde):
*   1) meteor  — gece göğünde kuyruklu yıldız; önce beyaz, sonra en yüksek nadirliğin rengine döner
*                (★3 mavi, ★4 mor, ★5 altın). ×10'da yanında küçük meteorlar. Sonunda beyaz parlama.
*   2) göster  — her asa tek tek: nadirlik renginde ışık ve ışınlar, asa sağdan süzülüp döner, ad,
*                yıldızlar birer birer, "YENİ" ya da "+toz". Tıkla/boşluk: önce animasyonu bitirir, sonra
*                sıradakine geçer.
*   3) özet    — ×10'da on kart yan yana. Tıkla: kapanır.
*   Sağ üstte "Atla": ×10'da özete, ×1'de doğrudan asaya geçer.
*/
local SG = SardonGacha
local ekran

local function Sirala(sonuc)
     local t = {}
     for i, s in ipairs(sonuc) do
          s.sira = i
          t[i] = s
     end
     table.sort(t, function(a, b)
          if a.y ~= b.y then return a.y > b.y end
          if (a.up and true or false) ~= (b.up and true or false) then return a.up and true or false end
          return a.sira < b.sira
     end)
     return t
end

local BEYAZ = Color(255, 255, 255)

local function RenkKaristir(a, b, t)
     t = math.Clamp(t, 0, 1)
     return Color(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t)
end

function SG.CekilisAc(sonuc, afisId)
     if IsValid(ekran) then ekran:Remove() end
     if not sonuc or #sonuc == 0 then return end

     local liste = Sirala(sonuc)
     local W, H = ScrW(), ScrH()
     local olc = H / 1080

     local p = vgui.Create("EditablePanel")
     ekran = p
     p:SetPos(0, 0)
     p:SetSize(W, H)
     p:MakePopup()
     p:SetKeyboardInputEnabled(true)
     p.liste = liste
     p.enY = liste[1].y
     p.coklu = #liste > 1
     p.evre = "meteor"
     p.t0 = RealTime()
     p.sira = 1
     p.zerreler = {}
     p.meteorSure = p.coklu and 3.3 or 2.7
     p.parladi = false
     p.tozToplam = 0
     for _, s in ipairs(liste) do p.tozToplam = p.tozToplam + (s.toz or 0) end

     -- ×10 küçük meteorlar (sonuçların nadirlik renkleriyle)
     p.kucukMeteor = {}
     if p.coklu then
          for i = 2, math.min(#liste, 6) do
               p.kucukMeteor[#p.kucukMeteor + 1] = { y = liste[i].y, gecik = 0.12 * i + math.Rand(0, 0.15), dx = math.Rand(-0.22, 0.18), dy = math.Rand(-0.08, 0.1), boy = math.Rand(0.45, 0.7) }
          end
     end

     SG.Cal("meteor")

     local function Evre(ad)
          p.evre = ad
          p.t0 = RealTime()
          if ad == "goster" then
               local s = p.liste[p.sira]
               if s then
                    SG.Cal(s.y)
                    if s.y >= 5 then timer.Simple(0.15, function() SG.Cal(4) end) end
               end
               p.zerreler = {}
          elseif ad == "ozet" then
               SG.Cal(4)
          end
     end

     local function Kapat()
          if p.kapaniyor then return end
          p.kapaniyor = RealTime()
          SG.Cal("tik")
     end
     p.Kapat = Kapat

     local function Ilerle()
          local g = RealTime() - p.t0
          if p.evre == "meteor" then
               if g < p.meteorSure - 0.45 then p.t0 = RealTime() - (p.meteorSure - 0.45) end
          elseif p.evre == "goster" then
               if g < 1.5 then
                    p.t0 = RealTime() - 1.5
               else
                    p.sira = p.sira + 1
                    if p.sira > #p.liste then
                         if p.coklu then Evre("ozet") else Kapat() end
                    else
                         Evre("goster")
                    end
               end
          elseif p.evre == "ozet" then
               if g < 0.9 then p.t0 = RealTime() - 0.9 else Kapat() end
          end
     end

     local function Atla()
          if p.coklu then
               if p.evre ~= "ozet" then Evre("ozet") else Kapat() end
          else
               if p.evre == "meteor" then
                    p.parladi = true
                    Evre("goster")
               else
                    Kapat()
               end
          end
     end
     p.Atla = Atla

     p.OnMousePressed = function(_, tus) if tus == MOUSE_LEFT then Ilerle() end end
     p.OnKeyCodePressed = function(_, tus)
          if tus == KEY_SPACE or tus == KEY_ENTER or tus == KEY_E then Ilerle()
          elseif tus == KEY_ESCAPE then Atla() end
     end

     local atla = p:Add("DButton")
     atla:SetText("")
     atla:SetSize(150 * olc, 44 * olc)
     atla:SetPos(W - 190 * olc, 36 * olc)
     atla.DoClick = function() Atla() end
     atla.Paint = function(s, w, h)
          local R = SG.R
          local a = p.evre == "ozet" and 0 or 1
          if a <= 0 then return end
          draw.RoundedBox(h / 2, 0, 0, w, h, s:IsHovered() and Color(255, 255, 255, 40) or Color(255, 255, 255, 16))
          SG.Yazi("Saltar  ›", SG.F(18 * olc, "orta"), w / 2, h / 2, s:IsHovered() and R.fildisiAcik or R.govde, 1, 1)
     end

     p.Think = function(s)
          if s.kapaniyor then
               if RealTime() - s.kapaniyor > 0.3 then s:Remove() end
               return
          end
          if input.IsKeyDown(KEY_ESCAPE) and gui.IsGameUIVisible() then gui.HideGameUI() Atla() end
          local g = RealTime() - s.t0
          if s.evre == "meteor" then
               if not s.parladi and g > s.meteorSure - 0.4 then
                    s.parladi = true
                    SG.Cal("parlama")
               end
               if g >= s.meteorSure then
                    Evre("goster")
               end
          end
          atla:SetVisible(s.evre ~= "ozet")
     end

     p.OnRemove = function(s)
          if ekran == s then ekran = nil end
          hook.Run("SardonGachaCekilisBitti")
     end

     p.Paint = function(s, w, h)
          local g = RealTime() - s.t0
          local kap = s.kapaniyor and (1 - SG.Kolay((RealTime() - s.kapaniyor) / 0.28)) or 1
          surface.SetAlphaMultiplier(kap)
          SG.ParAlfa = kap
          if s.evre == "meteor" then s:MeteorCiz(w, h, g)
          elseif s.evre == "goster" then s:GosterCiz(w, h, g)
          else s:OzetCiz(w, h, g) end
          SG.ParAlfa = 1
          surface.SetAlphaMultiplier(1)
     end

     /*
     *   1) Meteor
     */
     function p:MeteorCiz(w, h, g)
          SG.Kutu(0, 0, w, h, Color(3, 6, 10))
          SG.Parilti(w * 0.5, h * 1.05, w * 1.5, h * 0.7, Color(30, 48, 80), 120)
          SG.Parilti(w * 0.2, h * 0.15, w * 0.7, h * 0.5, Color(40, 30, 60), 70)
          SG.Yildizli(0, 0, w, h, 1, olc * 1.2)

          local sure = self.meteorSure
          local function Meteor(bas, son, u, renk, boy, alfa)
               if u <= 0 then return end
               local e = u ^ 1.5
               local hx, hy = bas.x + (son.x - bas.x) * e, bas.y + (son.y - bas.y) * e
               local aci = math.deg(math.atan2(-(son.y - bas.y), son.x - bas.x))
               for k = 28, 1, -1 do
                    local b = (u - k * 0.011)
                    if b > 0 then
                         local eb = b ^ 1.5
                         local x, y = bas.x + (son.x - bas.x) * eb, bas.y + (son.y - bas.y) * eb
                         local f = 1 - k / 29
                         SG.Parilti(x, y, (70 * f + 12) * boy * olc, nil, renk, 150 * f * f * alfa)
                    end
               end
               SG.PariltiDonuk(hx, hy, 520 * boy * olc, 46 * boy * olc, aci, renk, 120 * alfa)
               SG.Parilti(hx, hy, 190 * boy * olc, nil, renk, 230 * alfa)
               SG.Parilti(hx, hy, 60 * boy * olc, nil, BEYAZ, 255 * alfa)
               SG.Kivilcim(hx, hy, 150 * boy * olc, BEYAZ, 200 * alfa, RealTime() * 120)
          end

          local renkSon = SG.YildizIsik(self.enY)
          local u = math.Clamp(g / (sure * 0.8), 0, 1)
          local renk = RenkKaristir(BEYAZ, renkSon, (u - 0.3) / 0.45)
          Meteor({ x = w * 1.08, y = -h * 0.12 }, { x = w * 0.46, y = h * 0.6 }, u, renk, 1, 1)

          for _, m in ipairs(self.kucukMeteor) do
               local um = math.Clamp((g - m.gecik) / (sure * 0.75), 0, 1)
               local rm = RenkKaristir(BEYAZ, SG.YildizIsik(m.y), (um - 0.3) / 0.45)
               Meteor({ x = w * (1.08 + m.dx), y = -h * (0.12 - m.dy) }, { x = w * (0.46 + m.dx), y = h * (0.6 + m.dy) }, um, rm, m.boy, 0.85)
          end

          -- iniş parlaması
          local f = math.Clamp((g - (sure - 0.42)) / 0.3, 0, 1)
          if f > 0 then
               SG.Parilti(w * 0.46, h * 0.6, w * 2.4 * f, h * 2.4 * f, renkSon, 255 * f)
               SG.Kutu(0, 0, w, h, Color(255, 255, 255, 255 * SG.Yumusak(f)))
          end
     end

     /*
     *   2) Tek tek göster
     */
     function p:GosterCiz(w, h, g)
          local s = self.liste[self.sira]
          if not s then return end
          local R = SG.R
          local isik, renk = SG.YildizIsik(s.y), SG.YildizRenk(s.y)

          SG.Kutu(0, 0, w, h, Color(5, 8, 9))
          local nabiz = 0.9 + 0.1 * math.sin(RealTime() * 2)
          SG.Parilti(w * 0.58, h * 0.46, w * 1.2 * nabiz, h * 1.3 * nabiz, renk, 60 + (s.y - 3) * 35)
          SG.Yildizli(0, 0, w, h, 0.5, olc)
          if s.y >= 4 then
               local don = RealTime() * (s.y == 5 and 9 or 6)
               for i = 1, 12 do
                    SG.PariltiDonuk(w * 0.58, h * 0.46, w * 1.5, 26 * olc, don + i * 15, isik, s.y == 5 and 26 or 16)
               end
          end

          -- asa
          local ux = SG.Kolay(g / 0.75)
          local ax, ay, aw, ah = w * 0.27 + (1 - ux) * w * 0.22, h * 0.12, w * 0.62, h * 0.66
          SG.Parilti(ax + aw / 2, ay + ah / 2, aw * 0.75, ah * 0.55, isik, 120 * ux)
          SG.Parilti(ax + aw / 2, ay + ah / 2, aw * 0.3, ah * 0.25, BEYAZ, 60 * ux)
          self:Zerre(ax, ay, aw, ah, isik, ux)
          SG.AsaCiz(s.model, ax, ay, aw, ah, { aci = 32 + (1 - ux) * 40, donus = 25 + g * 32, dolu = 0.96, isik = isik, alfa = ux })

          -- ad ve yıldızlar
          local ta = SG.Kolay((g - 0.25) / 0.45)
          local tx = w * 0.1 - (1 - ta) * 40 * olc
          local ty = h * 0.64
          local af = SG.F(66 * olc, "baslik")
          SG.Gradyan(0, ty - 30 * olc, w * 0.55, 230 * olc, Color(0, 0, 0, 170), "sol", ta)
          SG.Kutu(tx - 24 * olc, ty - 6 * olc, 4 * olc, 150 * olc, renk, ta)
          SG.Yazi(s.ad, af, tx, ty, R.fildisiAcik, 0, 0, ta)
          if s.up then
               local nw = SG.Genislik(s.ad, af)
               SG.Yazi("UP!", SG.F(26 * olc, "kalin"), tx + nw + 14 * olc, ty - 4 * olc, isik, 0, 0, ta)
          end
          SG.Yildizlar(tx, ty + 82 * olc, s.y, 36 * olc, isik, ta, 0, (g - 0.55) / 0.14)

          local ny = ty + 134 * olc
          local na = SG.Kolay((g - 0.55 - s.y * 0.14) / 0.3)
          if s.yeni then
               local nf = SG.F(17 * olc, "kalin")
               local nw = SG.Genislik("NUEVA", nf) + 34 * olc
               draw.RoundedBox(15 * olc, tx, ny, nw, 30 * olc, ColorAlpha(R.altin, 255 * na))
               SG.Yazi("NUEVA", nf, tx + nw / 2, ny + 15 * olc, Color(28, 22, 12), 1, 1, na)
               SG.Yazi("Varita añadida a tu cuenta; equípala desde el menú de varitas.", SG.F(17 * olc), tx + nw + 14 * olc, ny + 15 * olc, R.govde, 0, 1, na)
          else
               SG.Ikon("toz", tx - 4 * olc, ny - 4 * olc, 38 * olc, na)
               SG.Yazi("Duplicado  ·  +" .. SG.Sayi(s.toz or 0) .. " " .. SG.Ayar.tozAd, SG.F(19 * olc, "orta"), tx + 42 * olc, ny + 15 * olc, R.govde, 0, 1, na)
          end

          -- sayaç ve ipucu
          if self.coklu then
               SG.Yazi(self.sira .. " / " .. #self.liste, SG.F(18 * olc, "orta"), 48 * olc, 50 * olc, R.soluk, 0, 0)
          end
          local ia = math.Clamp((g - 1.5) / 0.4, 0, 1) * (0.55 + 0.45 * math.sin(RealTime() * 3))
          SG.Yazi("Pulsa para continuar", SG.F(16 * olc, "orta"), w / 2, h - 46 * olc, R.soluk, 1, 1, ia)

          -- girişte parlamanın sönmesi
          local beyaz = 1 - SG.Kolay(g / 0.4)
          if beyaz > 0 and self.sira == 1 then SG.Kutu(0, 0, w, h, Color(255, 255, 255, 255 * beyaz)) end
          if s.y == 5 and g < 0.6 then SG.Parilti(w * 0.58, h * 0.46, w * 2 * (1 - g / 0.6), h * 2 * (1 - g / 0.6), isik, 200 * (1 - g / 0.6)) end
     end

     function p:Zerre(x, y, w, h, renk, alfa)
          local z = self.zerreler
          if math.random() < 0.6 and #z < 70 then
               local aci = math.Rand(0, math.pi * 2)
               z[#z + 1] = { x = x + w / 2 + math.cos(aci) * w * 0.12, y = y + h / 2 + math.sin(aci) * h * 0.12, vx = math.cos(aci) * math.Rand(40, 160) * olc, vy = math.sin(aci) * math.Rand(30, 120) * olc - 30 * olc, t0 = RealTime(), omur = math.Rand(1.2, 2.6), boy = math.Rand(12, 34) * olc, a = math.Rand(0, 90) }
          end
          for i = #z, 1, -1 do
               local q = z[i]
               local gg = RealTime() - q.t0
               if gg > q.omur then
                    table.remove(z, i)
               else
                    local za = math.sin(gg / q.omur * math.pi)
                    SG.Kivilcim(q.x + q.vx * gg, q.y + q.vy * gg, q.boy, renk, 230 * za * alfa, q.a + gg * 60)
               end
          end
     end

     /*
     *   3) Özet (×10)
     */
     function p:OzetCiz(w, h, g)
          local R = SG.R
          SG.Kutu(0, 0, w, h, Color(5, 8, 9))
          SG.Parilti(w * 0.5, h * 0.48, w * 1.3, h * 1.1, SG.YildizRenk(self.enY), 70)
          SG.Yildizli(0, 0, w, h, 0.6, olc)

          local ba = SG.Kolay(g / 0.4)
          SG.Yazi("Resultados del deseo", SG.F(44 * olc, "baslik"), w / 2, h * 0.09, R.fildisiAcik, 1, 1, ba)
          SG.Kesik(w / 2 - 220 * olc, h * 0.09 + 34 * olc, 440 * olc, R.cizgi, ba)

          local n = #self.liste
          local ara = math.floor(w * 0.008)
          local kw = math.floor(math.min(w * 0.084, (w * 0.92 - ara * (n - 1)) / n))
          local kh = math.floor(h * 0.56)
          local x0 = w / 2 - (n * kw + (n - 1) * ara) / 2
          local y0 = h * 0.19
          for i, s in ipairs(self.liste) do
               local ka = SG.Kolay((g - 0.05 * i) / 0.35)
               if ka > 0 then
                    local x = x0 + (i - 1) * (kw + ara) + (1 - ka) * 80 * olc
                    local isik, renk = SG.YildizIsik(s.y), SG.YildizRenk(s.y)
                    SG.Kutu(x, y0, kw, kh, Color(10, 14, 16), ka)
                    SG.Gradyan(x, y0 + kh * 0.25, kw, kh * 0.75, Color(renk.r, renk.g, renk.b, 150), "alt", ka)
                    SG.Parilti(x + kw / 2, y0 + kh * 0.42, kw * 1.7, kh * 0.6, isik, (40 + 25 * (s.y - 3)) * ka)
                    SG.Cerceve(x, y0, kw, kh, Color(isik.r, isik.g, isik.b, 150), ka)
                    SG.Kutu(x, y0, kw, 3 * olc, isik, ka)
                    SG.AsaCiz(s.model, x, y0 + kh * 0.05, kw, kh * 0.72, { aci = 74, donus = 30 + RealTime() * 22 + i * 25, dolu = 0.9, isik = isik, alfa = ka })
                    SG.Yildizlar(x + kw / 2, y0 + kh * 0.83, s.y, math.min(kw * 0.17, 24 * olc), isik, ka, 1)
                    if s.yeni then
                         local nf = SG.F(12 * olc, "kalin")
                         local nw = SG.Genislik("NUEVA", nf) + 16 * olc
                         draw.RoundedBox(9 * olc, x + kw / 2 - nw / 2, y0 + 10 * olc, nw, 18 * olc, ColorAlpha(R.altin, 255 * ka))
                         SG.Yazi("NUEVA", nf, x + kw / 2, y0 + 19 * olc, Color(28, 22, 12), 1, 1, ka)
                    else
                         SG.Yazi("+" .. SG.Sayi(s.toz or 0), SG.F(14 * olc, "orta"), x + kw / 2, y0 + kh * 0.93, R.govde, 1, 1, ka)
                    end
                    local af = SG.F(15 * olc, s.y >= 4 and "orta" or "govde")
                    for j, satir in ipairs(SG.Sar(s.ad, af, kw + ara)) do
                         if j > 2 then break end
                         SG.Yazi(satir, af, x + kw / 2, y0 + kh + 12 * olc + (j - 1) * 20 * olc, s.y >= 4 and isik or R.fildisi, 1, 0, ka)
                    end
               end
          end

          local ta = SG.Kolay((g - 0.8) / 0.4)
          if self.tozToplam > 0 then
               local m = "+" .. SG.Sayi(self.tozToplam) .. " " .. SG.Ayar.tozAd
               local mf = SG.F(20 * olc, "orta")
               local mw = SG.Genislik(m, mf) + 44 * olc
               SG.Ikon("toz", w / 2 - mw / 2, h * 0.86 - 20 * olc, 40 * olc, ta)
               SG.Yazi(m, mf, w / 2 - mw / 2 + 44 * olc, h * 0.86, R.fildisiAcik, 0, 1, ta)
          end
          local ia = ta * (0.55 + 0.45 * math.sin(RealTime() * 3))
          SG.Yazi("Pulsa para cerrar", SG.F(16 * olc, "orta"), w / 2, h - 46 * olc, R.soluk, 1, 1, ia)
     end

     return p
end

hook.Add("OnPauseMenuShow", "SardonGacha.Cekilis", function()
     if IsValid(ekran) then
          ekran.Atla()
          return false
     end
end)

-- Deneme: konsolda sardon_gacha_dene [1|10] — sunucuya gitmeden animasyonu oynatır (yalnız görüntü)
concommand.Add("sardon_gacha_dene", function(_, _, args)
     local n = tonumber(args[1]) == 10 and 10 or 1
     local havuz = {}
     for ad, sp in pairs(HpwRewrite and HpwRewrite:GetSpells() or {}) do
          if sp.IsSkin and sp.WorldModel then havuz[#havuz + 1] = { skin = ad, model = sp.WorldModel } end
     end
     if #havuz == 0 then return end
     local sonuc = {}
     for i = 1, n do
          local e = havuz[math.random(#havuz)]
          local y = (i == 1 and n == 10) and 5 or (math.random() < 0.25 and 4 or 3)
          sonuc[i] = { skin = e.skin, ad = SG.AsaAd(e.skin), model = e.model, y = y, yeni = math.random() < 0.5, toz = 15, up = y == 5 }
     end
     SG.CekilisAc(sonuc)
end, nil, "Reproduce la animación del deseo con resultados falsos (solo cliente).")
