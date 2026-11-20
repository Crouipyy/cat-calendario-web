-- "addons\\sardongacha\\lua\\sardon_gacha\\cl_5pencere.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
/*
*   Shine Store sekmesinin içindeki pencereler: onay, Dükkân (Adak/Yıldız Tozu → Dilek Bileti),
*   Ayrıntılar (oranlar, kurallar, havuz), Geçmiş. Hepsi sekmenin kök panelinin (SG.Magaza) üstüne
*   açılır; dışına ya da × düğmesine tıklayınca kapanır.
*/
local SG = SardonGacha

local function Yuzde(v, b)
     return "%" .. (string.format("%." .. (b or 1) .. "f", tonumber(v) or 0):gsub("%.", ","))
end
SG.Yuzde = Yuzde

function SG.Dugme(ebeveyn, x, y, w, h, metin, fn, tur)
     local b = ebeveyn:Add("DButton")
     b:SetPos(x, y)
     b:SetSize(w, h)
     b:SetText("")
     b.metin = metin
     b.DoClick = function(s) if s:IsEnabled() then SG.Cal("tik") fn(s) end end
     b.OnCursorEntered = function(s) if s:IsEnabled() then SG.Cal("uzerinde") end end
     b.Paint = function(s, pw, ph)
          local R = SG.R
          local ust, acik = s:IsHovered(), s:IsEnabled()
          local r = math.floor(ph / 2)
          if tur == "birincil" then
               draw.RoundedBox(r, 0, 0, pw, ph, ust and R.altinAcik or R.altin)
               draw.RoundedBox(r - 2, 2, 2, pw - 4, ph - 4, not acik and Color(150, 146, 132) or (ust and Color(252, 247, 233) or R.krem))
               SG.Yazi(s.metin, SG.F(ph * 0.4, "orta"), pw / 2, ph / 2, Color(84, 70, 48), 1, 1)
          else
               draw.RoundedBox(r, 0, 0, pw, ph, ust and acik and R.altinAcik or Color(190, 162, 104, acik and 200 or 70))
               draw.RoundedBox(r - 2, 2, 2, pw - 4, ph - 4, ust and acik and Color(26, 34, 29, 250) or Color(10, 16, 14, 245))
               SG.Yazi(s.metin, SG.F(ph * 0.4, "orta"), pw / 2, ph / 2, acik and (ust and R.fildisiAcik or R.fildisi) or R.sonuk, 1, 1)
          end
     end
     return b
end

/*
*   Pencere iskeleti. kurucu(ic, w, h, S, kok) içeriği kurar.
*/
function SG.Pencere(kok, baslik, tw, th, kurucu)
     if not IsValid(kok) then return end
     if IsValid(kok.pencere) then kok.pencere:Remove() end
     local KW, KH = kok:GetSize()
     local S = math.min(KW / 1640, KH / 860)
     local w, h = math.floor(tw * S), math.floor(th * S)
     local x, y = math.floor((KW - w) / 2), math.floor((KH - h) / 2)

     local ort = kok:Add("EditablePanel")
     ort:SetPos(0, 0)
     ort:SetSize(KW, KH)
     ort:MoveToFront()
     ort.t0 = RealTime()
     ort.Kapat = function()
          if ort.kapaniyor then return end
          ort.kapaniyor = RealTime()
          ort:SetMouseInputEnabled(false)
          timer.Simple(0.15, function() if IsValid(ort) then ort:Remove() end end)
     end
     ort.Paint = function(s, pw, ph)
          local R = SG.R
          local a = SG.Kolay((RealTime() - s.t0) / 0.2)
          if s.kapaniyor then a = a * (1 - SG.Kolay((RealTime() - s.kapaniyor) / 0.15)) end
          s:SetAlpha(255 * a)
          SG.Kutu(0, 0, pw, ph, Color(0, 0, 0, 175))
          SG.Kutu(x + 6 * S, y + 8 * S, w, h, Color(0, 0, 0, 120))
          SG.Kutu(x, y, w, h, Color(9, 14, 12, 252))
          SG.Parilti(x + w / 2, y, w * 0.8, 160 * S, R.altin, 26)
          SG.Cerceve(x, y, w, h, R.cizgi)
          SG.Koseler(x - 4 * S, y - 4 * S, w + 8 * S, h + 8 * S, 18 * S, R.altin)
          SG.Yazi(baslik, SG.F(28 * S, "baslik"), x + w / 2, y + 26 * S, R.fildisiAcik, 1, 0)
          SG.Kesik(x + 40 * S, y + 74 * S, w - 80 * S, R.cizgi)
          SG.Baklava(x + w / 2, y + 74 * S, 4 * S, R.altin, 1, true)
     end
     ort.OnMousePressed = function(s)
          local mx, my = s:CursorPos()
          if mx < x or mx > x + w or my < y or my > y + h then s.Kapat() end
     end

     local kapat = ort:Add("DButton")
     kapat:SetText("")
     kapat:SetPos(x + w - 46 * S, y + 16 * S)
     kapat:SetSize(30 * S, 30 * S)
     kapat.DoClick = function() SG.Cal("tik") ort.Kapat() end
     kapat.Paint = function(s, pw, ph)
          local c = s:IsHovered() and SG.R.altinAcik or SG.R.soluk
          surface.SetDrawColor(c.r, c.g, c.b, 255)
          for i = -1, 1 do
               surface.DrawLine(pw * 0.25 + i, ph * 0.25, pw * 0.75 + i, ph * 0.75)
               surface.DrawLine(pw * 0.75 + i, ph * 0.25, pw * 0.25 + i, ph * 0.75)
          end
     end

     local ic = ort:Add("EditablePanel")
     ic:SetPos(x + math.floor(30 * S), y + math.floor(90 * S))
     ic:SetSize(w - math.floor(60 * S), h - math.floor(116 * S))
     kok.pencere = ort
     kurucu(ic, ic:GetWide(), ic:GetTall(), S, ort)
     return ort
end

-- Kaydırılabilir tek tuval: yukseklik(w) yüksekliği, ciz(w, h) çizimi verir
local function Tuval(ic, w, h, ciz)
     local sp = ic:Add("DScrollPanel")
     sp:SetPos(0, 0)
     sp:SetSize(w, h)
     local bar = sp:GetVBar()
     bar:SetWide(6)
     bar:SetHideButtons(true)
     bar.Paint = function(_, bw, bh) SG.Kutu(0, 0, bw, bh, Color(255, 255, 255, 8)) end
     bar.btnGrip.Paint = function(_, bw, bh) draw.RoundedBox(3, 0, 0, bw, bh, Color(190, 162, 104, 120)) end
     local t = sp:Add("DPanel")
     t:SetWide(w - 14)
     t:SetTall(h)
     t.Paint = function(s, tw, th)
          local yeni = ciz(tw, th)
          if yeni and math.abs(yeni - th) > 1 then
               s:SetTall(math.max(yeni, 10))
               sp:InvalidateLayout()
          end
     end
     return sp, t
end

/*
*   Onay
*/
function SG.OnayAc(kok, baslik, metin, evetAd, evetFn, ikon)
     return SG.Pencere(kok, baslik, 660, 340, function(ic, w, h, S, ort)
          local p = ic:Add("DPanel")
          p:SetPos(0, 0)
          p:SetSize(w, h - 64 * S)
          p.Paint = function(_, pw)
               local yy = 4 * S
               if ikon then
                    SG.Ikon(ikon, pw / 2 - 28 * S, yy, 56 * S)
                    yy = yy + 66 * S
               end
               for _, s in ipairs(SG.Sar(metin, SG.F(18 * S), pw - 40 * S)) do
                    SG.Yazi(s, SG.F(18 * S), pw / 2, yy, SG.R.govde, 1)
                    yy = yy + 25 * S
               end
          end
          local bw, bh = 220 * S, 46 * S
          SG.Dugme(ic, w / 2 - bw - 10 * S, h - bh, bw, bh, "Cancelar", function() ort.Kapat() end)
          SG.Dugme(ic, w / 2 + 10 * S, h - bh, bw, bh, evetAd, function() ort.Kapat() evetFn() end, "birincil")
     end)
end

/*
*   Tienda: Ofrenda → ticket, Polvo estelar → ticket
*/
function SG.DukkanAc(kok)
     local ay = SG.Ayar
     return SG.Pencere(kok, "Tienda", 940, 610, function(ic, w, h, S)
          local kartlar = {
               { kaynak = "adak", ikon = "adak", ad = ay.adakAd, fiyat = math.max(1, ay.biletFiyat or 160) },
               { kaynak = "toz", ikon = "toz", ad = ay.tozAd, fiyat = math.max(1, ay.tozBilet or 75) },
          }
          local kw, kh = (w - 24 * S) / 2, h - 70 * S
          for i, k in ipairs(kartlar) do
               local kx = (i - 1) * (kw + 24 * S)
               local p = ic:Add("DPanel")
               p:SetPos(kx, 0)
               p:SetSize(kw, kh)
               k.adet = 1
               local function Sahip()
                    local adak, _, toz = SG.Cuzdan()
                    return k.kaynak == "adak" and adak or toz
               end
               local function En() return math.Clamp(math.floor(Sahip() / k.fiyat), 1, 100) end
               p.Paint = function(_, pw, ph)
                    local R = SG.R
                    SG.Kutu(0, 0, pw, ph, Color(14, 21, 18, 240))
                    SG.Cerceve(0, 0, pw, ph, R.cizgiSoluk)
                    SG.Parilti(pw / 2, 90 * S, pw * 0.8, 150 * S, i == 1 and R.altin or SG.YildizIsik(4), 40)
                    -- kaynak → bilet
                    local ik = 76 * S
                    SG.Ikon(k.ikon, pw / 2 - ik - 34 * S, 50 * S, ik)
                    SG.Yazi("›", SG.F(40 * S, "orta"), pw / 2, 50 * S + ik / 2, R.altin, 1, 1)
                    SG.Ikon("bilet", pw / 2 + 34 * S, 50 * S, ik)
                    SG.Yazi(k.ad .. "  →  " .. ay.biletAd, SG.F(20 * S, "orta"), pw / 2, 146 * S, R.fildisiAcik, 1)
                    SG.Yazi("1 " .. ay.biletAd .. " = " .. SG.Sayi(k.fiyat) .. " " .. k.ad, SG.F(16 * S), pw / 2, 174 * S, R.soluk, 1)
                    SG.Kesik(30 * S, 206 * S, pw - 60 * S, R.cizgiSoluk)
                    SG.Yazi("Tienes: " .. SG.Sayi(Sahip()) .. " " .. k.ad, SG.F(16 * S, "orta"), pw / 2, 222 * S, R.govde, 1)
                    -- adet
                    SG.Yazi(tostring(k.adet), SG.F(38 * S, "orta"), pw / 2, 290 * S, R.fildisiAcik, 1, 1)
                    local tutar = k.adet * k.fiyat
                    SG.Yazi("Total: " .. SG.Sayi(tutar) .. " " .. k.ad, SG.F(16 * S, "orta"), pw / 2, 326 * S, Sahip() >= tutar and R.altinAcik or R.hata, 1)
               end
               local bw = 46 * S
               SG.Dugme(p, kw / 2 - 120 * S, 267 * S, bw, bw, "−", function() k.adet = math.max(1, k.adet - 1) end)
               SG.Dugme(p, kw / 2 + 74 * S, 267 * S, bw, bw, "+", function() k.adet = math.min(100, k.adet + 1) end)
               SG.Dugme(p, kw / 2 + 128 * S, 267 * S, 70 * S, bw, "Máx.", function() k.adet = En() end)
               SG.Dugme(p, 30 * S, kh - 66 * S, kw - 60 * S, 48 * S, "Canjear", function()
                    if Sahip() < k.adet * k.fiyat then SG.Bildirim("No tienes suficiente " .. k.ad .. ".", "hata") return end
                    SG.TakasIste(k.kaynak, k.adet)
                    k.adet = 1
               end, "birincil")
          end
          local not_ = ic:Add("DPanel")
          not_:SetPos(0, kh + 12 * S)
          not_:SetSize(w, 58 * S)
          not_.Paint = function(_, pw)
               local yy = 0
               for _, s in ipairs(SG.Sar((ay.adakNasil or "") .. "  Si sale una varita que ya tienes, ganas " .. ay.tozAd .. ".", SG.F(15 * S), pw)) do
                    SG.Yazi(s, SG.F(15 * S), pw / 2, yy, SG.R.soluk, 1)
                    yy = yy + 21 * S
               end
          end
     end)
end

/*
*   Ayrıntılar: oranlar, kurallar, havuz
*/
function SG.AyrintiAc(kok, a)
     return SG.Pencere(kok, "Detalles · " .. a.ad, 1000, 680, function(ic, w, h, S)
          local oranlar, taban = SG.AsaOranlari(a)
          local ay = SG.Ayar
          local k5 = "Una varita ★5 llega como tarde en el deseo " .. a.h5 .. "."
          if (a.s5 or 0) > 0 and (a.a5 or 0) > 0 then k5 = k5 .. " Desde el deseo " .. a.s5 .. " la tasa sube " .. Yuzde(a.a5, 1) .. " por deseo." end
          local kurallar = { k5, "Cada " .. a.h4 .. " deseos sale al menos una varita ★4 o superior." }
          if a.tur ~= "standart" then
               kurallar[#kurallar + 1] = "Al obtener ★5, " .. Yuzde(a.up5, 0) .. " de probabilidad de varita destacada." .. (a.garanti and " Si no toca, la siguiente ★5 será la destacada." or "")
               kurallar[#kurallar + 1] = "Al obtener ★4, " .. Yuzde(a.up4, 0) .. " de ser una destacada." .. (a.garanti and " Si no toca, la siguiente ★4 será destacada." or "")
               kurallar[#kurallar + 1] = "Los contadores pity son comunes a todos los pósters de evento; siguen aunque cambies de póster."
          end
          kurallar[#kurallar + 1] = "Si repites una varita: ★3 " .. ay.toz3 .. ", ★4 " .. ay.toz4 .. ", ★5 " .. ay.toz5 .. " " .. ay.tozAd .. "."
          kurallar[#kurallar + 1] = "La varita se guarda en la cuenta y aparece en el menú de varitas de cada personaje. Las de gacha no tienen penalización de segunda varita."

          local gruplar = { [5] = {}, [4] = {}, [3] = {} }
          for i, e in ipairs(a.havuz or {}) do
               if gruplar[e.y] then gruplar[e.y][#gruplar[e.y] + 1] = { e = e, o = oranlar[i] or 0 } end
          end
          for _, g in pairs(gruplar) do table.sort(g, function(x, y) if x.e.up ~= y.e.up then return x.e.up end return x.o > y.o end) end

          Tuval(ic, w, h, function(tw)
               local R = SG.R
               local yy = 0
               local function Bolum(ad)
                    SG.Yazi(SG.Buyuk(ad), SG.F(13 * S, "kalin"), 0, yy, R.altin)
                    SG.Kutu(0, yy + 22 * S, tw, 1, R.cizgiSoluk)
                    yy = yy + 34 * S
               end
               Bolum("Probabilidades")
               local ort = { [5] = SG.Ortalama5(a), [4] = SG.Ortalama4(a) }
               for y = 5, 3, -1 do
                    SG.Yildizlar(0, yy, y, 20 * S, SG.YildizIsik(y), 1, 0)
                    SG.Yazi(SG.Yildiz[y].ad, SG.F(17 * S, "orta"), 130 * S, yy + 1 * S, R.fildisiAcik)
                    SG.Yazi("Base " .. Yuzde(taban[y], 3), SG.F(17 * S, "orta"), 360 * S, yy + 1 * S, R.govde)
                    if ort[y] then SG.Yazi("Media con pity " .. Yuzde(ort[y], 1), SG.F(17 * S), 580 * S, yy + 1 * S, R.soluk) end
                    yy = yy + 32 * S
               end
               yy = yy + 12 * S
               Bolum("Reglas")
               for _, k in ipairs(kurallar) do
                    local satir = SG.Sar(k, SG.F(16 * S), tw - 30 * S)
                    SG.Baklava(6 * S, yy + 10 * S, 3 * S, R.altin, 1, true)
                    for _, s in ipairs(satir) do
                         SG.Yazi(s, SG.F(16 * S), 22 * S, yy, R.govde)
                         yy = yy + 22 * S
                    end
                    yy = yy + 6 * S
               end
               yy = yy + 12 * S
               for y = 5, 3, -1 do
                    if #gruplar[y] > 0 then
                         Bolum("Varitas " .. SG.Yildiz[y].ad .. " (" .. #gruplar[y] .. ")")
                         for _, g in ipairs(gruplar[y]) do
                              local e = g.e
                              local renk = SG.YildizIsik(y)
                              SG.Kutu(0, yy, 3 * S, 26 * S, renk)
                              SG.Yazi(e.ad, SG.F(17 * S, "orta"), 16 * S, yy + 13 * S, R.fildisiAcik, 0, 1)
                              local nx = 16 * S + SG.Genislik(e.ad, SG.F(17 * S, "orta")) + 12 * S
                              if e.up and a.tur ~= "standart" and y >= 4 then
                                   SG.Yazi("UP!", SG.F(14 * S, "kalin"), nx, yy + 13 * S, renk, 0, 1)
                                   nx = nx + 40 * S
                              end
                              if SG.Elde(e.skin) then SG.Yazi("Ya la tienes", SG.F(13 * S), nx, yy + 13 * S, R.iyi, 0, 1) end
                              SG.Yazi(Yuzde(g.o, 3), SG.F(16 * S, "orta"), tw - 10 * S, yy + 13 * S, R.govde, 2, 1)
                              yy = yy + 32 * S
                         end
                         yy = yy + 10 * S
                    end
               end
               return yy + 10 * S
          end)
     end)
end

/*
*   Geçmiş
*/
function SG.GecmisAc(kok)
     SG.GecmisListe = nil
     SG.GecmisIste()
     return SG.Pencere(kok, "Historial de deseos", 1000, 680, function(ic, w, h, S)
          local basliklar = { { "Rareza", 0 }, { "Varita", 150 }, { "Póster", 470 }, { "Nota", 700 }, { "Hora", 860 } }
          local ust = ic:Add("DPanel")
          ust:SetPos(0, 0)
          ust:SetSize(w, 34 * S)
          ust.Paint = function(_, pw, ph)
               SG.Kutu(0, 0, pw, ph, Color(19, 28, 24))
               for _, b in ipairs(basliklar) do SG.Yazi(b[1], SG.F(14 * S, "kalin"), 12 * S + b[2] * S * (pw / (940 * S)), ph / 2, SG.R.altin, 0, 1) end
          end
          local sp = Tuval(ic, w, h - 40 * S, function(tw)
               local R = SG.R
               local liste = SG.GecmisListe
               if not liste then
                    SG.Yazi("Cargando…", SG.F(17 * S), tw / 2, 40 * S, R.soluk, 1)
                    return 100 * S
               end
               if #liste == 0 then
                    SG.Yazi("Aún no has hecho ningún deseo.", SG.F(17 * S), tw / 2, 40 * S, R.soluk, 1)
                    return 100 * S
               end
               local k = tw / (940 * S)
               local yy = 0
               for i, r in ipairs(liste) do
                    local renk = SG.YildizIsik(r.y)
                    if i % 2 == 0 then SG.Kutu(0, yy, tw, 34 * S, Color(255, 255, 255, 6)) end
                    SG.Yildizlar(12 * S, yy + 8 * S, r.y, 17 * S, renk, 1, 0)
                    SG.Yazi(r.ad, SG.F(16 * S, r.y >= 4 and "orta" or "govde"), 12 * S + 150 * S * k, yy + 17 * S, r.y >= 4 and renk or R.fildisi, 0, 1)
                    SG.Yazi(r.afis or "", SG.F(14 * S), 12 * S + 470 * S * k, yy + 17 * S, R.soluk, 0, 1)
                    SG.Yazi(r.yeni and "Nueva" or ("+" .. (r.toz or 0) .. " polvo"), SG.F(14 * S, "orta"), 12 * S + 700 * S * k, yy + 17 * S, r.yeni and R.iyi or R.soluk, 0, 1)
                    SG.Yazi(os.date("%d.%m.%Y %H:%M", r.t or 0), SG.F(14 * S), 12 * S + 860 * S * k, yy + 17 * S, R.soluk, 0, 1)
                    yy = yy + 34 * S
               end
               return yy
          end)
          sp:SetPos(0, 40 * S)
     end)
end
