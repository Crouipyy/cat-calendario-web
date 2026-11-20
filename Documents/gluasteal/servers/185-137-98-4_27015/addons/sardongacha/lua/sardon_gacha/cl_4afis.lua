-- "addons\\sardongacha\\lua\\sardon_gacha\\cl_4afis.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
/*
*   Gacha sayfası: Genshin dilek ekranı düzeni. Üstte afiş seçici küçük kartlar ve cüzdan, ortada
*   afiş kartı (yönetimin verdiği görsel URL, başlık, "Olasılık arttı!", kalan süre, öne çıkan ★5
*   asanın dönen 3B modeli ve ad levhası), altta Yıldız Tozu, Dükkân / Ayrıntılar / Geçmiş ve
*   Dilek ×1 / Dilek ×10. Tasarım alanı 1360×860; ölçek = min(w/1360, h/860), alan ortalanır.
*/
local SG = SardonGacha

local TW, TH = 1360, 860
local KART = { x = 40, y = 92, w = 1280, h = 618 }

local PANEL = {}

function PANEL:Init()
     self.secili = SG.SeciliAfisId
     self.kucukler = {}
     self.zerreler = {}
     self.surum = -1
     self.S, self.ox, self.oy = 1, 0, 0

     local function Dugme(boyaci, tikla)
          local b = self:Add("DButton")
          b:SetText("")
          b.Paint = boyaci
          b.DoClick = tikla
          b.OnCursorEntered = function(s) if s:IsEnabled() then SG.Cal("uzerinde") end end
          return b
     end

     self.cek1 = Dugme(function(b, w, h) self:DilekCiz(b, w, h, 1) end, function() self:Dile(1) end)
     self.cek10 = Dugme(function(b, w, h) self:DilekCiz(b, w, h, 10) end, function() self:Dile(10) end)

     local alt = { { "Tienda", function() SG.DukkanAc(SG.Magaza) end }, { "Detalles", function() local a = self:SeciliAfis() if a then SG.AyrintiAc(SG.Magaza, a) end end },
          { "Historial", function() SG.GecmisAc(SG.Magaza) end } }
     self.alt = {}
     for i, d in ipairs(alt) do
          self.alt[i] = Dugme(function(b, w, h) self:AltDugmeCiz(b, w, h, d[1]) end, function() SG.Cal("tik") d[2]() end)
     end
     self.arti = Dugme(function(b, w, h)
          local R = SG.R
          draw.RoundedBox(h / 2, 0, 0, w, h, b:IsHovered() and R.altinAcik or R.altin)
          surface.SetDrawColor(30, 24, 14, 255)
          local k, t = math.floor(w * 0.44), math.max(2, math.floor(w * 0.1))
          surface.DrawRect(w / 2 - k / 2, h / 2 - t / 2, k, t)
          surface.DrawRect(w / 2 - t / 2, h / 2 - k / 2, t, k)
     end, function() SG.Cal("tik") SG.DukkanAc(SG.Magaza) end)

     hook.Add("SardonGachaDurum", self, function() self.bekliyor = nil end)
     hook.Add("SardonGachaBildirim", self, function(_, _, tur) if tur == "hata" then self.bekliyor = nil end end)
end

function PANEL:Afisler() return SG.Durum and SG.Durum.a or {} end

function PANEL:SeciliAfis()
     local liste = self:Afisler()
     for _, a in ipairs(liste) do
          if a.id == self.secili then return a end
     end
     local a = liste[1]
     if a then self.secili = a.id SG.SeciliAfisId = a.id end
     return a
end

-- Öne çıkan ★5 (yoksa standart afişte havuzun ilk ★5'i) ve öne çıkan ★4'ler
local function OneCikanlar(a)
     local bes, dort = nil, {}
     for _, e in ipairs(a.havuz or {}) do
          if e.up and a.tur ~= "standart" then
               if e.y == 5 and not bes then bes = e elseif e.y == 4 then dort[#dort + 1] = e end
          end
     end
     if not bes and a.tur == "standart" then
          for _, e in ipairs(a.havuz or {}) do if e.y == 5 then bes = e break end end
     end
     return bes, dort
end
SG.OneCikanlar = OneCikanlar

function PANEL:KucukleriKur()
     for _, b in ipairs(self.kucukler) do if IsValid(b) then b:Remove() end end
     self.kucukler = {}
     local liste = self:Afisler()
     if #liste < 2 then return end
     for i, a in ipairs(liste) do
          local b = self:Add("DButton")
          b:SetText("")
          b.afis = a
          b.DoClick = function()
               if self.secili == a.id then return end
               SG.Cal("tik")
               self.secili = a.id
               SG.SeciliAfisId = a.id
               self.degisim = RealTime()
          end
          b.OnCursorEntered = function() SG.Cal("uzerinde") end
          b.Paint = function(s, w, h)
               local R = SG.R
               local sec = self.secili == a.id
               local mat = SG.UrlMat(a.gorsel)
               SG.Kutu(0, 0, w, h, R.zemin2)
               if mat then SG.Kapla(mat, 0, 0, w, h, sec and 1 or 0.55) else SG.Parilti(w * 0.6, h / 2, w, h * 1.4, SG.YildizIsik(5), sec and 80 or 40) end
               SG.Gradyan(0, h * 0.35, w, h * 0.65, Color(0, 0, 0, 200), "alt")
               SG.Yazi(a.ad, SG.F(h * 0.21, "orta"), w / 2, h - h * 0.08, sec and R.fildisiAcik or R.govde, 1, TEXT_ALIGN_BOTTOM)
               SG.Cerceve(0, 0, w, h, sec and R.altinAcik or R.cizgi, 1, sec and 2 or 1)
               if sec then SG.Baklava(w / 2, h, 4, R.altinAcik, 1, true) end
               if s:IsHovered() and not sec then SG.Kutu(0, 0, w, h, Color(255, 255, 255, 12)) end
          end
          self.kucukler[i] = b
     end
end

function PANEL:Think()
     if self.surum ~= SG.Surum then
          self.surum = SG.Surum
          self:KucukleriKur()
          self:InvalidateLayout(true)
     end
     local a = self:SeciliAfis()
     local var = a ~= nil
     self.cek1:SetVisible(var)
     self.cek10:SetVisible(var)
     for _, b in ipairs(self.alt) do b:SetVisible(var or b == self.alt[1] or b == self.alt[3]) end
end

function PANEL:PerformLayout(w, h)
     local S = math.min(w / TW, h / TH)
     self.S = S
     self.ox, self.oy = math.floor((w - TW * S) / 2), math.floor((h - TH * S) / 2)
     local function K(b, x, y, bw, bh)
          b:SetPos(self.ox + math.floor(x * S), self.oy + math.floor(y * S))
          b:SetSize(math.floor(bw * S), math.floor(bh * S))
     end
     K(self.cek1, 650, 742, 320, 98)
     K(self.cek10, 1000, 742, 320, 98)
     for i, b in ipairs(self.alt) do K(b, 40 + (i - 1) * 164, 794, 150, 46) end
     K(self.arti, 1168, 29, 30, 30)

     local n = #self.kucukler
     local kw, ara = 176, 16
     local x0 = TW / 2 - (n * kw + (n - 1) * ara) / 2
     for i, b in ipairs(self.kucukler) do K(b, x0 + (i - 1) * (kw + ara), 14, kw, 62) end
end

/*
*   Çizim
*/
function PANEL:X(x) return self.ox + x * self.S end
function PANEL:Y(y) return self.oy + y * self.S end

function PANEL:Paint(w, h)
     local S, R = self.S, SG.R
     local a = self:SeciliAfis()
     local gecis = SG.Kolay((RealTime() - (self.gecis or 0)) / 0.35)

     -- sol üst başlık
     SG.Ikon("bilet", self:X(40), self:Y(24), 36 * S, gecis)
     SG.Yazi("Deseo de varita", SG.F(26 * S, "baslik"), self:X(86), self:Y(42), R.fildisiAcik, 0, 1, gecis)

     -- cüzdan
     local adak, bilet = SG.Cuzdan()
     self:CuzdanHap(1004, 24, 200, "adak", adak, gecis)
     self:CuzdanHap(1214, 24, 106, "bilet", bilet, gecis)

     if not a then
          self:BosCiz(gecis)
          return
     end

     local dg = self.degisim and SG.Kolay((RealTime() - self.degisim) / 0.3) or 1
     self:KartCiz(a, self:X(KART.x), self:Y(KART.y), KART.w * S, KART.h * S, S, gecis * dg)

     -- alt sol: pity + toz
     local _, _, toz = SG.Cuzdan()
     local ay = SG.Ayar
     local p = SG.Durum and SG.Durum.p and SG.Durum.p[a.tur == "standart" and "standart" or "etkinlik"]
     if ay.pityGoster and p then
          local k5, k4 = math.max(1, (a.h5 or 90) - (p.p5 or 0)), math.max(1, (a.h4 or 10) - (p.p4 or 0))
          local metin = "★5 garantizado en " .. k5 .. " deseos   ·   ★4 en " .. k4 .. " deseos"
          if a.tur ~= "standart" and a.garanti and p.g5 == 1 then metin = metin .. "   ·   Próximo ★5 destacado garantizado" end
          SG.Yazi(metin, SG.F(15 * S, "orta"), self:X(40), self:Y(724), R.soluk, 0, 0, gecis)
     end
     SG.Ikon("toz", self:X(36), self:Y(748), 34 * S, gecis)
     SG.Yazi(SG.Sayi(toz), SG.F(20 * S, "orta"), self:X(76), self:Y(765), R.fildisiAcik, 0, 1, gecis)
     SG.Yazi(ay.tozAd, SG.F(14 * S), self:X(76) + SG.Genislik(SG.Sayi(toz), SG.F(20 * S, "orta")) + 10 * S, self:Y(766), R.soluk, 0, 1, gecis)
end

function PANEL:CuzdanHap(x, y, w, ikon, deger, alfa)
     local S, R = self.S, SG.R
     local px, py, pw, ph = self:X(x), self:Y(y), w * S, 40 * S
     draw.RoundedBox(ph / 2, px, py, pw, ph, Color(6, 10, 9, 200 * alfa))
     surface.SetDrawColor(R.altin.r, R.altin.g, R.altin.b, 70 * alfa)
     surface.DrawRect(px + ph / 2, py + ph - 1, pw - ph, 1)
     SG.Ikon(ikon, px - 4 * S, py - 4 * S, 48 * S, alfa)
     local sag = ikon == "adak" and (px + pw - 46 * S) or (px + pw - 16 * S)
     SG.Yazi(SG.Sayi(deger), SG.F(20 * S, "orta"), sag, py + ph / 2, R.fildisiAcik, 2, 1, alfa)
end

function PANEL:BosCiz(alfa)
     local S, R = self.S, SG.R
     local x, y, w, h = self:X(KART.x), self:Y(KART.y), KART.w * S, KART.h * S
     SG.Kutu(x, y, w, h, Color(8, 13, 11, 200 * alfa))
     SG.Cerceve(x, y, w, h, R.cizgi, alfa)
     SG.Koseler(x - 5 * S, y - 5 * S, w + 10 * S, h + 10 * S, 22 * S, R.altin, alfa)
     SG.Parilti(x + w / 2, y + h * 0.42, w * 0.5, h * 0.6, R.altin, 40 * alfa)
     SG.Ikon("bilet", x + w / 2 - 40 * S, y + h * 0.3, 80 * S, alfa * 0.8)
     SG.Yazi(SG.Durum and "No hay ningún póster de varita abierto" or "Cargando…", SG.F(34 * S, "baslik"), x + w / 2, y + h * 0.56, R.fildisiAcik, 1, 1, alfa)
     SG.Yazi("Cuando se abra el póster del nuevo periodo, aparecerá aquí. Sigue acumulando ofrendas.", SG.F(17 * S), x + w / 2, y + h * 0.64, R.govde, 1, 1, alfa)
end

function PANEL:KartCiz(a, x, y, w, h, S, alfa)
     local R = SG.R
     local isik5 = SG.YildizIsik(5)

     -- gölge + görsel
     SG.Kutu(x + 8 * S, y + 10 * S, w, h, Color(0, 0, 0, 110 * alfa))
     local mat, durum = SG.UrlMat(a.gorsel)
     SG.Kutu(x, y, w, h, Color(R.zemin2.r, R.zemin2.g, R.zemin2.b, 255 * alfa))
     if mat then
          SG.Kapla(mat, x, y, w, h, alfa)
     else
          SG.Parilti(x + w * 0.72, y + h * 0.45, w * 0.8, h * 1.1, isik5, 70 * alfa)
          SG.Parilti(x + w * 0.2, y + h * 0.8, w * 0.6, h * 0.6, SG.YildizIsik(4), 40 * alfa)
          SG.Yildizli(x, y, w, h, 0.8 * alfa, S)
          if durum == "iniyor" then SG.Yazi("Cargando imagen…", SG.F(14 * S), x + w - 18 * S, y + 14 * S, R.soluk, 2, 0, alfa) end
     end

     -- okunurluk perdesi (sol) ve ad levhası gölgesi (sağ alt)
     local perde = Color(6, 10, 9, 232)
     SG.Kutu(x, y, w * 0.24, h, perde, alfa)
     SG.Gradyan(x + math.floor(w * 0.24) - 1, y, w * 0.36 + 1, h, perde, "sol", alfa)
     SG.Gradyan(x + w * 0.4, y + h * 0.58, w * 0.6, h * 0.42, Color(0, 0, 0, 190), "alt", alfa)

     -- öne çıkan ★5 asa
     local bes, dort = OneCikanlar(a)
     if bes and a.model then
          local mx, my, mw, mh = x + w * 0.47, y + h * 0.04, w * 0.5, h * 0.62
          local nabiz = 0.85 + 0.15 * math.sin(RealTime() * 1.7)
          SG.Parilti(mx + mw / 2, my + mh / 2, mw * 0.95 * nabiz, mh * 0.9 * nabiz, isik5, 70 * alfa)
          SG.Parilti(mx + mw / 2, my + mh / 2, mw * 0.4, mh * 0.35, R.fildisiAcik, 40 * alfa)
          self:Zerreler(mx, my, mw, mh, isik5, alfa, S)
          local sx, sy = self:LocalToScreen(mx, my)
          SG.AsaCiz(bes.model, sx, sy, mw, mh, { aci = 30, donus = RealTime() * 28, dolu = 0.94, isik = isik5, alfa = alfa })
     end

     -- çerçeve
     SG.Cerceve(x, y, w, h, R.cizgi, alfa)
     SG.Koseler(x - 5 * S, y - 5 * S, w + 10 * S, h + 10 * S, 22 * S, R.altin, alfa)

     -- etiket hapı (çerçeveye taşar)
     local et = SG.Buyuk(a.etiket ~= "" and a.etiket or (a.tur == "standart" and "Deseo · Estándar" or "Deseo · Evento"))
     local ef = SG.F(15 * S, "kalin")
     local ew = SG.Genislik(et, ef) + 44 * S
     draw.RoundedBoxEx(17 * S, x - 12 * S, y - 16 * S, ew, 34 * S, Color(R.altin.r, R.altin.g, R.altin.b, 255 * alfa), true, true, false, true)
     SG.Yazi(et, ef, x - 12 * S + ew / 2, y + 1 * S, Color(28, 22, 12), 1, 1, alfa)

     -- başlık
     local lx, lw = x + 56 * S, 560 * S
     local bf = SG.F(58 * S, "baslik")
     local satir = SG.Sar(a.ad, bf, lw)
     local ty = y + 46 * S
     for i = 1, math.min(#satir, 2) do
          SG.Yazi(satir[i], bf, lx, ty, i == 1 and R.altinAcik or R.fildisiAcik, 0, 0, alfa)
          ty = ty + 64 * S
     end
     ty = ty + 14 * S
     SG.Kesik(lx, ty, 540 * S, R.cizgi, alfa)
     ty = ty + 22 * S

     -- olasılık kutusu
     local upVar = bes ~= nil and a.tur ~= "standart" or #dort > 0
     if upVar then
          SG.Yazi("¡Probabilidad aumentada!", SG.F(28 * S, "orta"), lx, ty, R.fildisiAcik, 0, 0, alfa)
          ty = ty + 42 * S
     end
     local kf = SG.F(18 * S, "orta")
     local kutuSatir = SG.Sar("Cada " .. (a.h4 or 10) .. " deseos, al menos una varita ★4 o superior.", kf, 480 * S)
     local kh = (#kutuSatir * 25 + 20) * S
     SG.Kutu(lx, ty, 540 * S, kh, Color(190, 162, 104, 46), alfa)
     SG.Kutu(lx, ty, 3 * S, kh, R.altinAcik, alfa)
     SG.Kivilcim(lx + 26 * S, ty + kh / 2, 26 * S, R.altinAcik, 230 * alfa, RealTime() * 20)
     for i, s in ipairs(kutuSatir) do
          SG.Yazi(s, kf, lx + 48 * S, ty + (10 + (i - 1) * 25) * S, R.fildisiAcik, 0, 0, alfa)
     end
     ty = ty + kh + 16 * S

     -- açıklama
     local ac = a.aciklama ~= "" and a.aciklama or (a.tur == "standart" and "Este póster no tiene fecha de cierre; todas las varitas salen con tasas estándar." or
          "La varita ★5 destacada sale con tasa aumentada durante este póster. Consulta Detalles para tasas y pool.")
     local af = SG.F(17 * S)
     local alanSon = y + h - 110 * S
     for _, s in ipairs(SG.Sar(ac, af, 530 * S)) do
          if ty + 22 * S > alanSon then break end
          SG.Yazi(s, af, lx, ty, R.govde, 0, 0, alfa)
          ty = ty + 23 * S
     end

     -- kalan süre
     local sy = y + h - 92 * S
     SG.Yazi("Tiempo restante", SG.F(17 * S, "orta"), lx, sy, R.altin, 0, 0, alfa)
     local kalan = (a.bit or 0) > 0 and SG.SureYazi(a.bit - SG.Simdi()) or "Sin límite"
     SG.Yazi(kalan, SG.F(22 * S, "orta"), lx, sy + 26 * S, R.fildisiAcik, 0, 0, alfa)

     -- ad levhası
     if bes then
          local nx, ny = x + w * 0.56, y + h - 168 * S
          local nf = SG.F(42 * S, "baslik")
          local yr = SG.Yildiz[5]
          SG.Gradyan(nx - 26 * S, ny - 8 * S, 560 * S, 104 * S, Color(0, 0, 0, 150), "sol", alfa)
          SG.Kutu(nx - 26 * S, ny - 8 * S, 3 * S, 104 * S, yr.renk, alfa)
          SG.Yazi(bes.ad, nf, nx, ny, R.fildisiAcik, 0, 0, alfa)
          if a.tur ~= "standart" then
               local nw = SG.Genislik(bes.ad, nf)
               SG.Yazi("UP!", SG.F(24 * S, "kalin"), nx + nw + 10 * S, ny - 6 * S, yr.isik, 0, 0, alfa)
          end
          SG.Yildizlar(nx, ny + 54 * S, 5, 28 * S, yr.isik, alfa, 0)
     end
     if #dort > 0 then
          local adlar = {}
          for i, e in ipairs(dort) do if i <= 3 then adlar[#adlar + 1] = e.ad end end
          SG.Yazi("★4 destacadas:  " .. table.concat(adlar, "  ·  "), SG.F(16 * S, "orta"), x + w - 40 * S, y + h - 30 * S, SG.YildizIsik(4), 2, 1, alfa)
     end
end

function PANEL:Zerreler(x, y, w, h, renk, alfa, S)
     local z = self.zerreler
     if math.random() < 0.35 and #z < 40 then
          z[#z + 1] = { x = x + w * math.Rand(0.15, 0.85), y = y + h * math.Rand(0.35, 0.95), vy = -math.Rand(14, 40) * S, t0 = RealTime(), omur = math.Rand(1.6, 3.4), boy = math.Rand(10, 26) * S, a = math.Rand(0, 360) }
     end
     for i = #z, 1, -1 do
          local p = z[i]
          local g = RealTime() - p.t0
          if g > p.omur then
               table.remove(z, i)
          else
               local za = math.sin(g / p.omur * math.pi)
               SG.Kivilcim(p.x + math.sin(g * 2 + i) * 6 * S, p.y + p.vy * g, p.boy, renk, 220 * za * alfa, p.a + g * 40)
          end
     end
end

function PANEL:DilekCiz(b, w, h, adet)
     local S, R = self.S, SG.R
     local a = self:SeciliAfis()
     local _, bilet = SG.Cuzdan()
     local bekle = self.bekliyor and RealTime() - self.bekliyor < 4
     local ust, bas = b:IsHovered() and not bekle, b:IsDown()
     local kenar = ust and R.altinAcik or R.altin
     local zemin = bekle and Color(176, 170, 152) or (bas and Color(226, 214, 186) or (ust and Color(252, 247, 233) or R.krem))
     local r = math.floor(h / 2)
     draw.RoundedBox(r, 0, 0, w, h, kenar)
     local k = math.max(2, math.floor(3 * S))
     draw.RoundedBox(r - k, k, k, w - k * 2, h - k * 2, zemin)
     -- iç ince çizgi ve süs
     local ic = math.floor(8 * S)
     surface.SetDrawColor(R.altin.r, R.altin.g, R.altin.b, 90)
     surface.DrawRect(r, ic, w - r * 2, 1)
     surface.DrawRect(r, h - ic - 1, w - r * 2, 1)
     SG.Baklava(r * 0.7, h / 2, 6 * S, R.altinKoyu, 0.7, false)
     SG.Baklava(w - r * 0.7, h / 2, 6 * S, R.altinKoyu, 0.7, false)

     local koyu = Color(84, 70, 48)
     SG.Yazi("Deseo ×" .. adet, SG.F(27 * S, "orta"), w / 2, h * 0.36, koyu, 1, 1)
     local yf = SG.F(21 * S, "orta")
     local metin = "× " .. adet
     local tw = SG.Genislik(metin, yf)
     local ik = 30 * S
     local bx = w / 2 - (ik + 6 * S + tw) / 2
     SG.Ikon("bilet", bx, h * 0.7 - ik / 2, ik)
     SG.Yazi(metin, yf, bx + ik + 6 * S, h * 0.7, bilet >= adet and koyu or Color(184, 72, 52), 0, 1)
     if not a then SG.Kutu(0, 0, w, h, Color(0, 0, 0, 120)) end
end

function PANEL:AltDugmeCiz(b, w, h, metin)
     local R = SG.R
     local ust = b:IsHovered()
     draw.RoundedBox(h / 2, 0, 0, w, h, ust and Color(226, 197, 136) or Color(190, 162, 104, 200))
     draw.RoundedBox(h / 2 - 2, 2, 2, w - 4, h - 4, ust and Color(26, 34, 29, 250) or Color(10, 16, 14, 240))
     SG.Yazi(metin, SG.F(h * 0.4, "orta"), w / 2, h / 2, ust and R.fildisiAcik or R.fildisi, 1, 1)
end

function PANEL:Dile(adet)
     local a = self:SeciliAfis()
     if not a or (self.bekliyor and RealTime() - self.bekliyor < 4) then return end
     local adak, bilet = SG.Cuzdan()
     local ay = SG.Ayar
     if bilet >= adet then
          self:Gonder(a, adet, false)
          return
     end
     local eksik = adet - bilet
     local fiyat = eksik * math.max(1, ay.biletFiyat or 160)
     if adak >= fiyat then
          SG.OnayAc(SG.Magaza, "No tienes suficientes " .. ay.biletAd,
               "¿Gastar " .. SG.Sayi(fiyat) .. " " .. ay.adakAd .. " por " .. eksik .. " " .. ay.biletAd .. "? (Tienes " .. SG.Sayi(adak) .. ".)",
               "Gastar y desear", function() self:Gonder(a, adet, true) end, "adak")
     else
          SG.OnayAc(SG.Magaza, "No tienes suficiente " .. ay.adakAd,
               "Necesitas " .. SG.Sayi(fiyat) .. " " .. ay.adakAd .. " para " .. eksik .. " " .. ay.biletAd .. "; tienes " .. SG.Sayi(adak) .. ". " .. (ay.adakNasil or ""),
               "Tienda", function() SG.DukkanAc(SG.Magaza) end, "adak")
     end
end

function PANEL:Gonder(a, adet, adakla)
     self.bekliyor = RealTime()
     SG.Cal("tik")
     SG.CekIste(a.id, adet, adakla)
end

vgui.Register("SardonGacha.Afis", PANEL, "EditablePanel")
