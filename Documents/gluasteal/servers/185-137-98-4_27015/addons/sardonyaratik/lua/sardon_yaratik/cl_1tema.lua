-- "addons\\sardonyaratik\\lua\\sardon_yaratik\\cl_1tema.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- [sardon] yaratik :: istemci teması (Karakter Gelişimi / iksir kazanının "Celestial" görünümü)
--
-- Y.TuvalYap(w, h): tasarım alanı (ör. 1600×900) → ekrana ortalanmış ölçekli çizim yardımcıları.
-- Paneller opak tema renkleriyle çizilir (istemci alfayı lineer karıştırıyor; düşük alfalı beyaz
-- gri görünür). 2B parıltı: Sprite malzemeleri surface ile çizilmediği için RT'ye bir kez radyal
-- doku çizilir, toplamalı karışımla basılır.

local Y = SardonYaratik

local function Renk(hex, a)
     return Color(tonumber(hex:sub(2, 3), 16), tonumber(hex:sub(4, 5), 16), tonumber(hex:sub(6, 7), 16), a and math.Round(a * 255) or 255)
end
Y.HexRenk = Renk

Y.R = {
     soluk = Renk("#e8dbb6"), altin = Renk("#bea268"), parlak = Renk("#f2e0b3"), ust = Renk("#c4ac7a"),
     yazi = Renk("#c1c9b4"), sonuk = Renk("#99a88b"), kilit = Renk("#71868b"),
     zemin = Color(7, 18, 13), zemin2 = Color(12, 26, 20), satir = Color(16, 32, 25), satirSecili = Color(30, 46, 32),
     cizgi = Color(58, 70, 52),
     tamam = Renk("#b4d08f"), uyari = Renk("#e0c280"), hata = Renk("#d0745c"), ates = Renk("#f0a050"),
     aclik = Renk("#d9a25f"), temizlik = Renk("#7fb6d6"), sevgi = Renk("#d98aa6"), bag = Renk("#c9b6ee"),
     egitim = Renk("#b4d08f"), olum = Renk("#8c8f96"),
}

------------------------------------------------------------------------ yazı tipleri

local AILE = {
     [400] = {font = "Montserrat Medium", weight = 400},
     [600] = {font = "Montserrat SemiBold", weight = 600},
     kitap = {font = "Playfair Display", weight = 400, carpan = 1.12},
     isim = {font = "Playfair Display SemiBold", weight = 600, carpan = 1.12},
     baslik = {font = "Cinzel SemiBold", weight = 600},
}

local fontlar = {}
-- px: ekran pikseli (ölçek uygulanmış)
function Y.Font(px, kalin)
     local stil = AILE[kalin or 400] or AILE[400]
     px = math.max(9, math.Round(px * (stil.carpan or 1)))
     local ad = "SardonYaratik_" .. px .. "_" .. tostring(kalin or 400)
     if not fontlar[ad] then
          surface.CreateFont(ad, {font = stil.font, size = px, weight = stil.weight, antialias = true, extended = true})
          fontlar[ad] = true
     end
     return ad
end

local BUYUK = {["i"] = "İ", ["ı"] = "I", ["ç"] = "Ç", ["ş"] = "Ş", ["ğ"] = "Ğ", ["ü"] = "Ü", ["ö"] = "Ö"}
local HARF = "[%z\1-\127\194-\244][\128-\191]*"
function Y.Buyuk(s)
     return (tostring(s):gsub(HARF, function(c) return BUYUK[c] or c end)):upper()
end
Y.HARF = HARF

------------------------------------------------------------------------ 2B parıltı

local parMat
local function ParlakDokuCiz()
     local rt = GetRenderTargetEx("sardon_yaratik_parilti", 128, 128, RT_SIZE_LITERAL, MATERIAL_RT_DEPTH_NONE, 4 + 8 + 256, 0, IMAGE_FORMAT_RGB888)
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
     parMat = parMat or CreateMaterial("sardon_yaratik_parilti_m", "UnlitGeneric", {["$basetexture"] = rt:GetName(), ["$vertexcolor"] = 1, ["$vertexalpha"] = 1})
     parMat:SetTexture("$basetexture", rt)
end
local parHazir = false
hook.Add("PreRender", "SardonYaratik.Parilti", function()
     if parHazir then return end
     parHazir = true
     ParlakDokuCiz()
end)
hook.Add("OnScreenSizeChanged", "SardonYaratik.Parilti", function() parHazir = false end)

-- ekran pikseli cinsinden merkez ve boy
function Y.Parilti(x, y, boy, renk, alfa)
     if not parMat then return end
     local k = math.Clamp((alfa or 255) / 255, 0, 1)
     render.OverrideBlend(true, BLEND_ONE, BLEND_ONE, BLENDFUNC_ADD)
     surface.SetMaterial(parMat)
     surface.SetDrawColor(renk.r * k, renk.g * k, renk.b * k, 255)
     surface.DrawTexturedRect(x - boy / 2, y - boy / 2, boy, boy)
     render.OverrideBlend(false)
     draw.NoTexture()
end

-- 3B parçacık malzemesi
Y.MatNokta = CreateMaterial("sardon_yaratik_nokta", "UnlitGeneric", {
     ["$basetexture"] = "particle/particle_glow_04",
     ["$additive"] = 1, ["$vertexcolor"] = 1, ["$vertexalpha"] = 1, ["$nocull"] = 1,
})

------------------------------------------------------------------------ tuval

-- Tasarım alanı çizim yardımcıları. Her ekran kendi tuvalini kurar (ölçekler birbirini bozmasın).
function Y.TuvalYap(TW, TH)
     local T = {S = 1, OX = 0, OY = 0, TW = TW, TH = TH}
     local R = Y.R

     function T.Olc(w, h)
          local s = math.min(w / TW, h / TH)
          T.S, T.OX, T.OY = s, (w - TW * s) / 2, (h - TH * s) / 2
     end
     local function X(x) return T.OX + x * T.S end
     local function Yy(y) return T.OY + y * T.S end
     T.X, T.Y = X, Yy

     -- tasarım koordinatına geri (fare)
     function T.Geri(px, py) return (px - T.OX) / T.S, (py - T.OY) / T.S end

     function T.Ton(c, a)
          surface.SetDrawColor(c.r, c.g, c.b, (a or 1) * (c.a or 255))
     end

     function T.Dolu(x, y, w, h)
          surface.DrawRect(X(x), Yy(y), math.max(1, w * T.S), math.max(1, h * T.S))
     end

     function T.Cerceve(x, y, w, h)
          surface.DrawOutlinedRect(X(x), Yy(y), math.max(1, w * T.S), math.max(1, h * T.S), 1)
     end

     function T.Cizgi(x1, y1, x2, y2)
          surface.DrawLine(X(x1), Yy(y1), X(x2), Yy(y2))
     end

     function T.Font(boy, kalin) return Y.Font(boy * T.S * 1.15, kalin) end

     -- hiza 0 sol, 1 orta, 2 sağ; y satır merkezi; genişliği (tasarım px) döndürür
     function T.Yazi(metin, boy, kalin, x, y, renk, hiza, aralik, alfa)
          metin = tostring(metin)
          surface.SetFont(T.Font(boy, kalin))
          surface.SetTextColor(renk.r, renk.g, renk.b, (alfa or 1) * (renk.a or 255))
          local w, th = surface.GetTextSize(metin)
          local bos = (aralik and aralik > 0) and math.Round(aralik * T.S) or 0
          if bos > 0 then w = w + bos * math.max(0, (utf8.len(metin) or #metin) - 1) end
          local px = math.Round(X(x) - (hiza == 1 and w / 2 or (hiza == 2 and w or 0)))
          local py = math.Round(Yy(y) - th / 2)
          if bos == 0 then
               surface.SetTextPos(px, py)
               surface.DrawText(metin)
          else
               for harf in metin:gmatch(HARF) do
                    surface.SetTextPos(px, py)
                    surface.DrawText(harf)
                    px = px + surface.GetTextSize(harf) + bos
               end
          end
          return w / T.S
     end

     function T.Olcu(metin, boy, kalin)
          surface.SetFont(T.Font(boy, kalin))
          local w = surface.GetTextSize(tostring(metin))
          return w / T.S
     end

     function T.Sar(metin, boy, kalin, genislik)
          surface.SetFont(T.Font(boy, kalin))
          local satirlar, sat = {}, ""
          for kelime in tostring(metin or ""):gmatch("%S+") do
               local dene = sat == "" and kelime or (sat .. " " .. kelime)
               if sat ~= "" and surface.GetTextSize(dene) > genislik * T.S then
                    satirlar[#satirlar + 1] = sat
                    sat = kelime
               else
                    sat = dene
               end
          end
          if sat ~= "" then satirlar[#satirlar + 1] = sat end
          return satirlar
     end

     local kose = {{}, {}, {}, {}}
     function T.Baklava(cx, cy, h)
          kose[1].x, kose[1].y = X(cx), Yy(cy - h)
          kose[2].x, kose[2].y = X(cx + h), Yy(cy)
          kose[3].x, kose[3].y = X(cx), Yy(cy + h)
          kose[4].x, kose[4].y = X(cx - h), Yy(cy)
          draw.NoTexture()
          surface.DrawPoly(kose)
     end

     -- Celestial çerçeve: opak koyu zemin + ince altın çizgi + köşe baklavaları
     function T.Kutu(x, y, w, h, zemin)
          T.Ton(zemin or R.zemin, 1)
          T.Dolu(x, y, w, h)
          T.Ton(R.cizgi, 1)
          T.Cerceve(x, y, w, h)
          T.Ton(R.altin, 0.85)
          T.Baklava(x, y, 3.5) T.Baklava(x + w, y, 3.5) T.Baklava(x, y + h, 3.5) T.Baklava(x + w, y + h, 3.5)
     end

     -- yatay çubuk: oran 0..1
     function T.Cubuk(x, y, w, h, oran, renk, zemin)
          T.Ton(zemin or R.satir, 1)
          T.Dolu(x, y, w, h)
          oran = math.Clamp(oran or 0, 0, 1)
          if oran > 0 then
               T.Ton(renk, 1)
               T.Dolu(x, y, w * oran, h)
          end
     end

     local DAIRE_N = 48
     local daire = {}
     for i = 1, DAIRE_N + 2 do daire[i] = {} end

     -- dolu daire dilimi (saat yönünde a0 → a1, radyan; 0 = sağ)
     function T.Dilim(cx, cy, r, a0, a1)
          if a1 - a0 <= 0.001 then return end
          local n = math.max(3, math.ceil(DAIRE_N * (a1 - a0) / (math.pi * 2)))
          daire[1].x, daire[1].y = X(cx), Yy(cy)
          for i = 0, n do
               local a = a0 + (a1 - a0) * i / n
               daire[i + 2].x, daire[i + 2].y = X(cx + math.cos(a) * r), Yy(cy + math.sin(a) * r)
          end
          for i = n + 3, DAIRE_N + 2 do daire[i] = nil end
          draw.NoTexture()
          surface.DrawPoly(daire)
          for i = 1, DAIRE_N + 2 do daire[i] = daire[i] or {} end
     end

     -- halka (yay) çizgisi: kalınlık t
     function T.Yay(cx, cy, r, t, a0, a1)
          local n = math.max(2, math.ceil(64 * (a1 - a0) / (math.pi * 2)))
          for i = 0, n - 1 do
               local b0 = a0 + (a1 - a0) * i / n
               local b1 = a0 + (a1 - a0) * (i + 1) / n
               local p = {
                    {x = X(cx + math.cos(b0) * (r - t / 2)), y = Yy(cy + math.sin(b0) * (r - t / 2))},
                    {x = X(cx + math.cos(b0) * (r + t / 2)), y = Yy(cy + math.sin(b0) * (r + t / 2))},
                    {x = X(cx + math.cos(b1) * (r + t / 2)), y = Yy(cy + math.sin(b1) * (r + t / 2))},
                    {x = X(cx + math.cos(b1) * (r - t / 2)), y = Yy(cy + math.sin(b1) * (r - t / 2))},
               }
               draw.NoTexture()
               surface.DrawPoly(p)
          end
     end

     function T.Isik(x, y, r, renk, alfa)
          Y.Parilti(X(x), Yy(y), r * 2 * T.S, renk, alfa)
     end

     function T.Icinde(mx, my, x, y, w, h)
          return mx >= x and mx <= x + w and my >= y and my <= y + h
     end

     return T
end

------------------------------------------------------------------------ bildirimler

Y.Bildirimler = Y.Bildirimler or {}

local BILDIRIM_RENK = {
     iyi = Y.R.tamam, hata = Y.R.hata, bilgi = Y.R.soluk, nadir = Renk("#ecb852"), olum = Y.R.olum,
}

function Y.Bildirim(metin, tur)
     table.insert(Y.Bildirimler, 1, {metin = metin, tur = tur or "bilgi", t = RealTime()})
     while #Y.Bildirimler > 4 do table.remove(Y.Bildirimler) end
     MsgC(Color(201, 174, 119), "[Yaratık] ", color_white, metin, "\n")
     if tur == "hata" then
          surface.PlaySound("buttons/button10.wav")
     elseif tur == "nadir" then
          surface.PlaySound("ambient/levels/canals/windchime2.wav")
     else
          surface.PlaySound("buttons/button9.wav")
     end
end

local SURE = 6

hook.Add("HUDPaint", "SardonYaratik.Bildirim", function()
     local liste = Y.Bildirimler
     if #liste == 0 then return end
     local s = math.max(ScrH() / 1080, 0.6)
     local y = ScrH() * 0.16
     local simdi = RealTime()
     local font = Y.Font(17 * s, 600)

     for i = #liste, 1, -1 do
          if simdi - liste[i].t > SURE then table.remove(liste, i) end
     end

     for i, b in ipairs(liste) do
          local gecen = simdi - b.t
          local a = math.Clamp(math.min(gecen / 0.25, (SURE - gecen) / 0.6), 0, 1)
          local renk = BILDIRIM_RENK[b.tur] or Y.R.soluk
          surface.SetFont(font)
          local metin = b.metin
          local tw, th = surface.GetTextSize(metin)
          local maks = ScrW() * 0.6
          if tw > maks then
               -- uzun bildirim iki satıra bölünür
               local orta = math.floor(#metin / 2)
               local bosluk = metin:find(" ", orta, true) or orta
               b.satir = b.satir or {metin:sub(1, bosluk), metin:sub(bosluk + 1)}
          end
          local satirlar = b.satir or {metin}
          local gen = 0
          for _, s2 in ipairs(satirlar) do gen = math.max(gen, (surface.GetTextSize(s2))) end
          local h = (th + 4) * #satirlar + 16 * s
          local x = ScrW() / 2 - gen / 2 - 22 * s

          surface.SetDrawColor(7, 18, 13, 235 * a)
          surface.DrawRect(x, y, gen + 44 * s, h)
          surface.SetDrawColor(renk.r, renk.g, renk.b, 200 * a)
          surface.DrawRect(x, y, 3 * s, h)
          surface.SetDrawColor(58, 70, 52, 255 * a)
          surface.DrawOutlinedRect(x, y, gen + 44 * s, h, 1)

          for j, s2 in ipairs(satirlar) do
               draw.SimpleText(s2, font, ScrW() / 2, y + 8 * s + (j - 1) * (th + 4), Color(renk.r, renk.g, renk.b, 255 * a), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
          end
          y = y + h + 6 * s
     end
end)
