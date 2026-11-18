-- "addons\\sardonbakanlik\\lua\\sardon_bakanlik\\cl_3hud.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Bakanlık :: oyun içi katman (defter kapalıyken). Sunucunun "Not" paketlerini işler:
--   not          daireler arası not: soluk mor kâğıt uçak ekranın sağından süzülür, sol üste konup açılır
--   ferman       parşömen bildirim (atama, takdir, ruhsat, TABU, hüküm…), mum mühürle kapanır
--   kararname    yeni kararname (herkese)
--   ceza         sana kesilen para cezası
--   cigirtkan    vadesi geçen borç: kızıl zarf önünde patlar, bağırır (cigirtkanses: çevredekilere)
--   azkaban      hapis kararı (perde + Azkaban kartı; tutukluyken soğuk renk)
--   tehdit       tehdit seviyesi değişti (şerit)
--   hedef / hedefsil / ekiphedef / ekipkonum   yön işaretleri
--   priorifx     Priori Incantatem: asadan yükselen hayalet yankılar (dünyada)
--   oy / delil / rozet / tabuhissi
-- Düz Lua (çevrimdışı çizim düzeneğinde de çalışır).

local B = SardonBakanlik
local U = B.UI
local R = U.R

local notlar = {}      -- kâğıt uçak kartları
local fermanlar = {}   -- parşömenler (sırayla, tek tek)
local hedefler = {}    -- [anahtar] = {pos, baslik, renk, bitis}
local ekip = {}        -- ekip arkadaşlarının son konumu
local olaylar = {}     -- tek seferlik efektler (çığırtkan, tehdit şeridi, azkaban perdesi)
local priori = {}      -- dünyadaki yankılar

-- HUD ölçeği: ekranın sol üstünden, yükseklik 900 birim
local function HudOlcek()
     U.S = ScrH() / U.TH
     U.OX, U.OY = 0, 0
     return ScrW() / U.S
end

local function Vec(t) return Vector(tonumber(t.x) or 0, tonumber(t.y) or 0, tonumber(t.z) or 0) end

local function TusAdi()
     local tus = SardonConfig and SardonConfig.Get and SardonConfig:Get("bakanlik")
     local ad = tus and input.GetKeyName(tus)
     return ad and B.Buyuk(ad) or "B"
end

----------------------------------------------------------------------------------------
-- Paketler
----------------------------------------------------------------------------------------
local ISLE = {}

ISLE["not"] = function(t)
     table.insert(notlar, 1, {veri = t, an = RealTime(), pos = t.konumlu and Vec(t) or nil})
     while #notlar > 4 do table.remove(notlar) end
     surface.PlaySound("physics/cardboard/cardboard_box_impact_soft" .. math.random(1, 3) .. ".wav")
     if (tonumber(t.oncelik) or 0) >= 4 then surface.PlaySound("ambient/alarms/warningbell1.wav") end
end

local function Ferman(baslik, metin, imza, ust, muhur)
     fermanlar[#fermanlar + 1] = {baslik = baslik, metin = metin or "", imza = imza or "", ust = ust, muhur = muhur ~= false}
end

ISLE.ferman = function(t) Ferman(t.baslik, t.metin, t.imza, "Ministerio de Magia") end
ISLE.kararname = function(t) Ferman(t.baslik, t.metin, t.imza, (t.ad or "Decreto del Ministerio") .. " N.º " .. tostring(t.no)) end
ISLE.delil = function(t) Ferman(t.baslik, t.metin, "Presentado por: " .. tostring(t.sunan), "Wizengamot · " .. tostring(t.turAd), false) end

ISLE.ceza = function(t)
     Ferman("Multa · " .. B.Para(t.tutar), tostring(t.gerekce) .. "\n\nPara pagar, usa la tecla del expediente (" .. TusAdi() .. ") o /Sicil › Ventanilla del ciudadano. Plazo: " .. B.SureUzun(t.vade) .. ".",
          "Impuesta por: " .. tostring(t.memur), "Ministerio de Magia · Sanciones")
     chat.AddText(R.kizil, "[Ministerio] ", color_white, tostring(t.memur) .. " te ha impuesto una multa de " .. B.Para(t.tutar) .. ": " .. tostring(t.gerekce))
end

ISLE.cigirtkan = function(t)
     olaylar.cigirtkan = {an = RealTime(), tutar = t.tutar, gerekce = t.gerekce}
     surface.PlaySound("npc/stalker/go_alert2a.wav")
end

ISLE.cigirtkanses = function(t)
     chat.AddText(R.kizil, "[Gritador] ", color_white, "El sobre rojo a nombre de " .. tostring(t.ad) .. " grita delante de todos: ",
          R.kizil, B.Buyuk("¡Debes " .. B.Para(t.tutar) .. " al Ministerio! ¡Paga de inmediato!"))
end

ISLE.azkaban = function(t)
     olaylar.azkaban = {an = RealTime(), sure = t.sure, suc = t.suc, veren = t.veren}
     surface.PlaySound("ambient/levels/citadel/strange_talk" .. math.random(1, 11) .. ".wav")
end

ISLE.tehdit = function(t)
     olaylar.tehdit = {an = RealTime(), seviye = t.seviye, eski = t.eski}
     if t.seviye == 2 then surface.PlaySound("ambient/alarms/klaxon1.wav") else surface.PlaySound("buttons/bell1.wav") end
end

ISLE.hedef = function(t)
     hedefler["olay" .. t.olay] = {pos = Vec(t), baslik = t.baslik, alt = t.bolge, renk = R.altinAcik, olay = t.olay}
end

ISLE.hedefsil = function(t) hedefler["olay" .. tostring(t.olay)] = nil end

ISLE.ekiphedef = function(t)
     hedefler.ekip = {pos = Vec(t), baslik = "Objetivo de equipo · " .. tostring(t.ad), alt = t.bolge, renk = R.mavi, bitis = RealTime() + 90}
     surface.PlaySound("buttons/blip1.wav")
end

ISLE.ekipkonum = function(t)
     ekip = {an = RealTime(), uyeler = t.uyeler or {}}
end

ISLE.priorifx = function(t)
     priori[#priori + 1] = {e = t.e, m = t.m, an = CurTime(), sure = tonumber(t.sure) or 4}
end

ISLE.oy = function(t)
     Ferman("Votación del Wizengamot", tostring(t.baslik) .. "\n\nPara votar, usa la tecla del expediente (" .. TusAdi() .. ") › Wizengamot. Tiempo: " .. tostring(t.sure) .. " s.", "", "Convocatoria del tribunal", false)
     surface.PlaySound("buttons/bell1.wav")
end

ISLE.rozet = function(t)
     olaylar.rozet = {an = RealTime(), ad = t.ad, unvan = t.unvan, daire = t.daire}
     surface.PlaySound("physics/cardboard/cardboard_box_impact_soft2.wav")
end

ISLE.tabuhissi = function()
     olaylar.tabu = {an = RealTime()}
     surface.PlaySound("ambient/wind/wind_snippet" .. math.random(1, 5) .. ".wav")
end

B.Kanca("SardonBakanlikNot", "SardonBakanlik.HUD", function(t)
     local f = istable(t) and ISLE[t.tur or ""]
     if f then f(t) end
end)

----------------------------------------------------------------------------------------
-- Çizim parçaları
----------------------------------------------------------------------------------------
local TUR_ETIKET = {onay = "Confirmación", aranan = "Orden"}

local function NotCiz(sw)
     local simdi = RealTime()
     local y = 24
     for i = #notlar, 1, -1 do
          local n = notlar[i]
          local t = simdi - n.an
          if t > B.Ayar.NotSure + 0.6 then table.remove(notlar, i) end
     end

     for i, n in ipairs(notlar) do
          local v = n.veri
          local t = simdi - n.an
          local w, h = 380, 92
          local renk = B.OncelikRenk[tonumber(v.oncelik) or 2] or R.ada
          local cikis = t > B.Ayar.NotSure and (t - B.Ayar.NotSure) / 0.6 or 0

          if t < 0.85 then
               -- uçuş: sağ kenardan kavisle sol üste
               local k = U.Kolay(t / 0.85)
               local bx, by = sw + 60, 140 + i * 30
               local hx, hy = 24 + 30, y + h / 2
               local x = Lerp(k, bx, hx)
               local yy = Lerp(k, by, hy) - math.sin(k * math.pi) * 90
               local boy = 64 - 20 * k
               local mat = B.Doku("ucak")
               if mat then
                    surface.SetMaterial(mat)
                    surface.SetDrawColor(255, 255, 255, 255)
                    surface.DrawTexturedRectRotated(U.X(x), U.Y(yy), boy * U.S, boy * U.S, 180 + 20 * math.sin(k * 6))
                    draw.NoTexture()
               else
                    U.Baklava(x, yy, boy * 0.3, R.mor, 1)
               end
               U.Parilti(x, yy, 60, R.mor, 60)
          else
               local ac = U.Kolay((t - 0.85) / 0.3)
               local hx = 24 - cikis * 420
               surface.SetAlphaMultiplier(math.Clamp(1 - cikis, 0, 1))
               U.Kutu(hx, y, w * ac, h, R.zeminKoyu, 0.94)
               U.Gecis(hx, y, w * ac, h, R.mor, 0.12, "l")
               U.Cerceve(hx, y, w * ac, h, renk, 0.85)
               U.Kutu(hx, y, 3, h, renk, 1)
               if ac > 0.9 then
                    local mat = B.Doku("ucak")
                    if mat then U.Resim(mat, hx + w - 54, y + 8, 36, 36, R.beyaz, 0.55) end
                    U.Etiket((B.OlayTur[v.olayTur or ""] and B.OlayTur[v.olayTur].ad) or TUR_ETIKET[v.olayTur] or "Aviso", hx + 16, y + 16, renk, 0, 9)
                    U.Yazi(U.Kisalt(tostring(v.baslik), 15, 600, w - 80), 15, 600, hx + 16, y + 38, R.fildisiAcik)
                    local alt = tostring(v.bolge or "")
                    if n.pos and IsValid(LocalPlayer()) then alt = alt .. " · " .. math.floor(LocalPlayer():GetPos():Distance(n.pos) / 52.5) .. " m" end
                    U.Yazi(U.Kisalt(alt, 12, 700, w - 40), 12, 700, hx + 16, y + 58, R.ada)
                    U.Yazi("Expediente: " .. TusAdi(), 10, 700, hx + w - 14, y + 76, R.soluk, 2)
                    U.Cubuk(hx + 16, y + 76, w - 120, 2, 1 - t / B.Ayar.NotSure, renk)
               end
               surface.SetAlphaMultiplier(1)
          end
          y = y + h + 10
     end
end

local function FermanCiz(sw)
     local f = fermanlar[1]
     if not f then return end
     if not f.an then
          f.an = RealTime()
          surface.PlaySound("physics/cardboard/cardboard_box_impact_soft4.wav")
     end

     local t = RealTime() - f.an
     local sure = 7 + math.min(6, #f.metin / 40)
     if t > sure + 0.5 then
          table.remove(fermanlar, 1)
          return
     end

     local w = 560
     local satirlar = U.Sar(f.metin, 13, 700, w - 80)
     local h = 120 + #satirlar * 19 + (f.imza ~= "" and 22 or 0)
     local x = sw / 2 - w / 2
     local y = 70
     local acilma = U.Kolay(t / 0.45)
     local kapanma = t > sure and (t - sure) / 0.5 or 0
     local gh = h * acilma

     surface.SetAlphaMultiplier(1 - kapanma)
     local kagit = B.Doku("kagit")
     if kagit then
          U.Resim(kagit, x, y, w, gh, Color(255, 248, 232), 0.97)
     else
          U.Kutu(x, y, w, gh, Color(226, 208, 166), 0.97)
     end
     -- rulo uçları
     U.Kutu(x - 8, y - 6, w + 16, 12, Color(176, 150, 104), 1)
     U.Kutu(x - 8, y + gh - 6, w + 16, 12, Color(176, 150, 104), 1)

     if acilma > 0.95 then
          local murekkep = Color(52, 34, 22)
          if f.ust then U.Yazi(B.Buyuk(f.ust), 10, 600, x + w / 2, y + 28, Color(120, 84, 48), 1, 2.4) end
          U.Yazi(U.Kisalt(f.baslik, 22, 600, w - 60), 22, 600, x + w / 2, y + 58, murekkep, 1)
          U.SusCizgi(x + 60, y + 78, w - 120, Color(120, 84, 48), 0.8)
          for i, s in ipairs(satirlar) do U.Yazi(s, 13, 700, x + 40, y + 90 + (i - 0.5) * 19, murekkep) end
          if f.imza ~= "" then U.Yazi("— " .. f.imza, 12, 700, x + w - 40, y + h - 28, Color(90, 60, 36), 2) end

          if f.muhur then
               local mt = t - 0.6
               if mt > 0 then
                    local vur = U.Kolay(mt / 0.16)
                    local boy = 70 * (2.2 - 1.2 * vur)
                    local mat = B.Doku("mum")
                    if mat then U.Resim(mat, x + 40 - boy / 2 + 30, y + h - 40 - boy / 2, boy, boy, R.beyaz, math.min(1, mt / 0.1)) end
                    if not f.ses then
                         f.ses = true
                         surface.PlaySound("physics/wood/wood_box_impact_hard3.wav")
                    end
               end
          end
     end
     surface.SetAlphaMultiplier(1)
end

local function OlaylarCiz(sw)
     local simdi = RealTime()

     -- tehdit şeridi
     local th = olaylar.tehdit
     if th then
          local t = simdi - th.an
          if t > 6 then olaylar.tehdit = nil else
               local tanim = B.Tehdit[th.seviye] or B.Tehdit[0]
               local a = math.min(1, t / 0.3) * (t > 5.4 and (6 - t) / 0.6 or 1)
               -- notların ve fermanın altında, ekranın üst üçte birinde bir şerit
               local by = 300
               surface.SetAlphaMultiplier(a)
               U.Kutu(0, by, sw, 58, R.zeminKoyu, 0.9)
               U.Gecis(0, by, sw / 2, 58, tanim.renk, 0.25, "r")
               U.Gecis(sw / 2, by, sw / 2, 58, tanim.renk, 0.25, "l")
               U.Kutu(0, by, sw, 1, tanim.renk, 1)
               U.Kutu(0, by + 57, sw, 1, tanim.renk, 1)
               U.Yazi("NIVEL DE AMENAZA: " .. B.Buyuk(tanim.ad), 18, 600, sw / 2, by + 22, tanim.renk, 1, 3)
               U.Yazi(tanim.alt, 12, 700, sw / 2, by + 44, R.fildisi, 1)
               surface.SetAlphaMultiplier(1)
          end
     end

     -- çığırtkan
     local c = olaylar.cigirtkan
     if c then
          local t = simdi - c.an
          if t > 5 then olaylar.cigirtkan = nil else
               local cx, cy = sw / 2, 420
               if t < 0.9 then
                    local titre = (t / 0.9) * 8
                    local mat = B.Doku("zarf")
                    local boy = 120 + t * 60
                    if mat then U.Resim(mat, cx - boy / 2 + math.Rand(-titre, titre), cy - boy / 2 + math.Rand(-titre, titre), boy, boy) end
               else
                    local k = (t - 0.9) / 4.1
                    for i = 1, 14 do
                         local a = i * 0.45 + k * 2
                         local r = 60 + k * 420 * (0.6 + (i % 4) * 0.15)
                         U.Kutu(cx + math.cos(a) * r, cy + math.sin(a) * r * 0.6 + k * 200, 12, 7, R.kizil, 1 - k)
                    end
                    U.Kutu(0, cy - 70, sw, 140, R.siyah, 0.55 * (1 - k))
                    local yazi = B.Buyuk("¡Debes " .. B.Para(c.tutar) .. " al Ministerio!")
                    local sars = (1 - k) * 6
                    U.Yazi(yazi, 34, 600, cx + math.Rand(-sars, sars), cy - 30 + math.Rand(-sars, sars), R.kizil, 1, 2, 1 - k * 0.6)
                    U.Yazi("¡PAGA YA!", 26, 600, cx + math.Rand(-sars, sars), cy + 14, R.kizil, 1, 3, 1 - k * 0.6)
                    U.Yazi(tostring(c.gerekce), 13, 700, cx, cy + 50, R.fildisi, 1, nil, 1 - k)
               end
          end
     end

     -- rozet
     local r = olaylar.rozet
     if r then
          local t = simdi - r.an
          if t > 6 then olaylar.rozet = nil else
               local a = math.min(1, t / 0.25) * (t > 5.4 and (6 - t) / 0.6 or 1)
               local w, h = 360, 170
               local x, y = sw / 2 - w / 2, 560
               surface.SetAlphaMultiplier(a)
               U.Kutu(x, y, w, h, R.zemin, 0.96)
               U.Cerceve(x, y, w, h, R.altin, 1)
               U.Cerceve(x + 4, y + 4, w - 8, h - 8, R.cizgi, 0.6)
               U.Resim(B.Doku("muhur"), x + 18, y + 26, 118, 118)
               U.Etiket("Ministerio de Magia · Identidad", x + 152, y + 32, R.ust, 0, 9)
               U.Yazi(U.Kisalt(tostring(r.ad), 18, 600, w - 170), 18, 600, x + 152, y + 64, R.fildisiAcik)
               U.Yazi(U.Kisalt(tostring(r.unvan), 13, 700, w - 170), 13, 700, x + 152, y + 92, R.altinAcik)
               U.Yazi(U.Kisalt(B.DaireAd(r.daire), 11, 700, w - 170), 11, 700, x + 152, y + 116, R.ada)
               surface.SetAlphaMultiplier(1)
          end
     end

     -- tabu hissi
     local tb = olaylar.tabu
     if tb then
          local t = simdi - tb.an
          if t > 4 then olaylar.tabu = nil else
               local a = math.sin(math.min(1, t / 4) * math.pi)
               U.Kutu(0, 0, sw, U.TH, R.siyah, 0.35 * a)
               U.Yazi("Tu palabra quedó suspendida en el aire… algo te ha encontrado.", 18, 600, sw / 2, U.TH / 2, R.mor, 1, 1.5, a)
          end
     end
end

-- Azkaban: hüküm perdesi + tutukluyken alt kart
local function AzkabanCiz(sw)
     local ply = LocalPlayer()
     local a = olaylar.azkaban
     if a then
          local t = RealTime() - a.an
          if t > 6 then olaylar.azkaban = nil else
               local perde = t < 0.4 and t / 0.4 or (t > 5 and (6 - t) or 1)
               U.Kutu(0, 0, sw, U.TH, R.siyah, 0.92 * perde)
               U.Yazi("AZKABAN", 54, 600, sw / 2, 380, R.fildisi, 1, 12, perde)
               U.Yazi(B.SureUzun(a.sure), 22, 600, sw / 2, 440, R.mavi, 1, 2, perde)
               U.Yazi(U.Kisalt(tostring(a.suc), 14, 700, 900), 14, 700, sw / 2, 476, R.govde, 1, nil, perde)
               U.Yazi("Sentencia dictada por: " .. tostring(a.veren), 12, 700, sw / 2, 500, R.soluk, 1, nil, perde)
          end
     end

     if not ply:GetNW2Bool(B.NW_TUTUKLU, false) then return end
     local kalan = math.max(0, ply:GetNW2Float(B.NW_TUTUKLU_BITIS, 0) - CurTime())
     local w = 300
     local x, y = sw / 2 - w / 2, U.TH - 120
     U.Kutu(x, y, w, 66, R.zeminKoyu, 0.86)
     U.Cerceve(x, y, w, 66, R.mavi, 0.7)
     U.Etiket("Azkaban · pena restante", x + w / 2, y + 18, R.mavi, 1, 9)
     U.Yazi(B.Sure(kalan), 24, 600, x + w / 2, y + 44, R.fildisi, 1)
end

-- Yön işareti: ekrandaysa baklava + yazı, değilse kenarda ok
local function Isaret(pos, baslik, alt, renk, sw)
     local ply = LocalPlayer()
     local ekran = pos:ToScreen()
     local mesafe = ply:GetPos():Distance(pos)
     local metre = math.floor(mesafe / 52.5)

     local x, y = ekran.x / U.S, ekran.y / U.S
     local kenar = 40
     local ekranda = ekran.visible and x > kenar and x < sw - kenar and y > kenar and y < U.TH - kenar
     if not ekranda then
          -- ekranın arkasındaysa yönü çevir
          local cx, cy = sw / 2, U.TH / 2
          local dx, dy = x - cx, y - cy
          if not ekran.visible then dx, dy = -dx, -dy end
          local uz = math.max(1, math.sqrt(dx * dx + dy * dy))
          dx, dy = dx / uz, dy / uz
          local olc = math.min((sw / 2 - kenar) / math.max(0.001, math.abs(dx)), (U.TH / 2 - kenar) / math.max(0.001, math.abs(dy)))
          x, y = cx + dx * olc, cy + dy * olc
     end

     local nabiz = 0.6 + 0.4 * math.sin(RealTime() * 3)
     U.Parilti(x, y, 46, renk, 80 * nabiz)
     U.Baklava(x, y, 9, renk, 1)
     U.BaklavaCizgi(x, y, 14, renk, 0.7)
     if ekranda then
          U.Yazi(U.Kisalt(baslik, 13, 600, 260), 13, 600, x, y - 26, R.fildisi, 1)
          U.Yazi(metre .. " m" .. (alt and alt ~= "" and (" · " .. alt) or ""), 11, 700, x, y + 24, renk, 1)
     else
          U.Yazi(metre .. " m", 11, 700, x, y + 22, renk, 1)
     end
     return mesafe
end

local function HedeflerCiz(sw)
     local simdi = RealTime()
     for k, h in pairs(hedefler) do
          if h.bitis and h.bitis < simdi then
               hedefler[k] = nil
          else
               local mesafe = Isaret(h.pos, h.baslik, h.alt, h.renk, sw)
               -- olay yerine varınca işaret 5 sn sonra kalkar
               if mesafe < 160 then
                    h.vardi = h.vardi or simdi
                    if simdi - h.vardi > 5 then hedefler[k] = nil end
               end
          end
     end

     -- ekip arkadaşları (yalnız mesaideyken)
     if ekip.uyeler and RealTime() - (ekip.an or 0) < 6 and B.Gorevde(LocalPlayer()) then
          local ben = LocalPlayer():EntIndex()
          for _, u in ipairs(ekip.uyeler) do
               if u.e ~= ben then
                    local e = Entity(u.e)
                    local pos = (IsValid(e) and e:IsPlayer()) and (e:GetPos() + Vector(0, 0, 84)) or (Vec(u) + Vector(0, 0, 84))
                    local ekran = pos:ToScreen()
                    if ekran.visible then
                         local x, y = ekran.x / U.S, ekran.y / U.S
                         U.Baklava(x, y, 5, R.mavi, 0.85)
                         U.Yazi(u.ad, 11, 700, x, y - 14, R.mavi, 1, nil, 0.85)
                    end
               end
          end
     end
end

-- Aranan etiketi: mesaideki görevli baktığı aranan kişinin başında görür
local function ArananCiz(sw)
     local ply = LocalPlayer()
     if not B.Gorevde(ply) then return end
     local hedef = ply:GetEyeTrace().Entity
     if not (IsValid(hedef) and hedef:IsPlayer() and hedef:GetNW2Bool(B.NW_ARANAN, false)) then return end
     if hedef:GetPos():DistToSqr(ply:GetPos()) > 900 * 900 then return end
     local ekran = (hedef:GetPos() + Vector(0, 0, 86)):ToScreen()
     if not ekran.visible then return end
     local x, y = ekran.x / U.S, ekran.y / U.S
     U.Rozet("Buscado", x - 40, y, R.kizil, true)
end

-- 11-13 opt: pcall'a her karede yeni kapanış yerine dosya düzeyinde işlev (sw parametreyle); hata yakalama aynı
local function HudCiz(sw)
     HedeflerCiz(sw)
     ArananCiz(sw)
     AzkabanCiz(sw)
     NotCiz(sw)
     FermanCiz(sw)
     OlaylarCiz(sw)
end

B.Kanca("HUDPaint", "SardonBakanlik.HUD", function()
     if IsValid(B.Defter) then return end
     local sw = HudOlcek()
     local ok, hata = pcall(HudCiz, sw)
     surface.SetAlphaMultiplier(1)
     if not ok and not B.HudHata then
          B.HudHata = true
          ErrorNoHalt("[Sardon Bakanlık] HUD: " .. tostring(hata) .. "\n")
     end
end)

----------------------------------------------------------------------------------------
-- Dünya: Azkaban soğuğu ve Priori yankıları
----------------------------------------------------------------------------------------
local soguk = {
     ["$pp_colour_addr"] = 0, ["$pp_colour_addg"] = 0.01, ["$pp_colour_addb"] = 0.04, ["$pp_colour_brightness"] = -0.04,
     ["$pp_colour_contrast"] = 1.05, ["$pp_colour_colour"] = 0.35, ["$pp_colour_mulr"] = 0, ["$pp_colour_mulg"] = 0, ["$pp_colour_mulb"] = 0.2,
}

B.Kanca("RenderScreenspaceEffects", "SardonBakanlik.Azkaban", function()
     local ply = LocalPlayer()
     if IsValid(ply) and ply:GetNW2Bool(B.NW_TUTUKLU, false) and DrawColorModify then DrawColorModify(soguk) end
end)

local matIsik = Material("sprites/light_glow02_add")

local function AsaUcu(ent)
     if not IsValid(ent) then return nil end
     local kemik = ent:LookupBone("ValveBiped.Bip01_R_Hand")
     if kemik then
          local pos = ent:GetBonePosition(kemik)
          if pos then return pos end
     end
     return ent:GetPos() + Vector(0, 0, 50)
end

B.Kanca("PostDrawTranslucentRenderables", "SardonBakanlik.Priori", function(derinlik, gokyuzu)
     if gokyuzu or #priori == 0 then return end
     local simdi = CurTime()
     render.SetMaterial(matIsik)

     for i = #priori, 1, -1 do
          local p = priori[i]
          local t = simdi - p.an
          local ent = Entity(p.e)
          if t > p.sure + 1.5 or not IsValid(ent) then
               table.remove(priori, i)
          else
               local bas = AsaUcu(ent)
               local mud = Entity(p.m)
               if IsValid(mud) then
                    -- inceleyen asadan şüpheliye ince gümüş iplik
                    local mbas = AsaUcu(mud)
                    if mbas then
                         render.DrawBeam(mbas, bas, 1.2, 0, 1, Color(200, 230, 220, 160 * math.min(1, t)))
                    end
               end
               -- yükselen hayalet yankılar: her biri bir büyünün silik izi
               for k = 0, 9 do
                    local f = ((t * 0.55) + k / 10) % 1
                    local yuk = f * 70
                    local aci = k * 0.63 + t * 1.4
                    local pos = bas + Vector(math.cos(aci) * (6 + f * 14), math.sin(aci) * (6 + f * 14), yuk)
                    local a = 220 * (1 - f) * math.min(1, t / 0.4) * (t > p.sure and math.max(0, 1 - (t - p.sure) / 1.5) or 1)
                    render.DrawSprite(pos, 18 - f * 8, 18 - f * 8, Color(190, 240, 215, a))
               end
          end
     end
end)
