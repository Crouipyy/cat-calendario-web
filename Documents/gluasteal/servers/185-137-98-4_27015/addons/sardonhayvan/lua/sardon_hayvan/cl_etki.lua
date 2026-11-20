-- "addons\\sardonhayvan\\lua\\sardon_hayvan\\cl_etki.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Hayvan :: vuruş etkilerinin ekran efekti (sunucu tarafı sv_etki.lua).
--
-- Kenetleşme kenar efektiyle aynı dil: etki renginde kanama vinyeti + damarlar
-- (dokular [hogwarts] wand fightingmanager.lua'dan, HpwRewrite.FM.Doku), dalgalı
-- kenar ışığı, kalp atışı nabzı. Her etkinin kendine özgü parçacığı var:
--   zehir    : alttan yükselen kabarcıklar, yeşil renk kayması
--   kanama   : üstten süzülen damlalar, güçlü nabız, solgun renk
--   yanma    : alttan yükselen közler, sıcak renk
--   donma    : kenarlarda kar parıltısı, soğuk/solgun renk
--   elektrik : kenarlardan içeri çakan kıvılcım yayları, ani parlamalar
-- Efekt yalnızca etki varken hook'ludur; bitince hook'lar kaldırılır.

local aktif = {}   -- [etki] = {bitis, darbe, level, beat, spawn}
-- Legacy HUD durum şeridi okur (cl_legacy_2durum.lua)
if SardonHayvan then SardonHayvan.EtkiAktif = aktif end
local motes = {}
local arcs = {}
local hooklu = false

local gradU = Material("vgui/gradient-u") -- üst opak
local gradD = Material("vgui/gradient-d") -- alt opak
local gradL = Material("vgui/gradient-l") -- sol opak
local gradR = Material("vgui/gradient-r") -- sağ opak
local glow = Material("sprites/light_glow02_add")

surface.CreateFont("SardonHayvan.Etki", {font = "Montserrat SemiBold", size = 20, weight = 600, extended = true})
surface.CreateFont("SardonHayvan.EtkiSn", {font = "Montserrat Medium", size = 16, weight = 500, extended = true})

local renkGolge = Color(0, 0, 0, 170)
local renkArka = Color(10, 12, 18, 170)
local renkYazi = Color(240, 236, 226)

local function Doku(ad)
     local FM = HpwRewrite and HpwRewrite.FM
     return FM and FM.Doku and FM.Doku(ad) or nil
end

local function Renk(etki)
     local e = SardonHayvan.Etkiler and SardonHayvan.Etkiler[etki]
     return e and e.renk or color_white
end

/*
*   parçacıklar
*/

local MAKS_MOTE = 110

local function MoteEkle(etki, w, h, lvl)
     if (#motes >= MAKS_MOTE) then return end

     local m = {etki = etki, life = 0, seed = math.Rand(0, 100)}

     if (etki == "zehir") then
          -- kabarcık: alt kenarda ya da yanların alt yarısında doğar, yükselir
          if (math.random() < 0.6) then
               m.x, m.y = math.Rand(0, w), h + 8
          else
               m.x = math.random(0, 1) == 0 and math.Rand(0, 60 + lvl * 60) or w - math.Rand(0, 60 + lvl * 60)
               m.y = math.Rand(h * 0.55, h)
          end
          m.vx, m.vy = 0, -math.Rand(25, 60)
          m.max = math.Rand(1.4, 2.6)
          m.size = math.Rand(5, 13)
     elseif (etki == "kanama") then
          -- damla: üst kenardan aşağı süzülür, hızlanır
          m.x, m.y = math.Rand(w * 0.04, w * 0.96), math.Rand(-4, 10 + lvl * 30)
          m.vx, m.vy = 0, math.Rand(8, 22)
          m.ay = math.Rand(30, 70)
          m.max = math.Rand(1.2, 2.2)
          m.size = math.Rand(3, 6)
     elseif (etki == "yanma") then
          -- köz: altta ve yanların altında doğar, titreyerek yükselir
          if (math.random() < 0.7) then
               m.x, m.y = math.Rand(0, w), h + 6
          else
               m.x = math.random(0, 1) == 0 and math.Rand(0, 40) or w - math.Rand(0, 40)
               m.y = math.Rand(h * 0.4, h)
          end
          m.vx, m.vy = math.Rand(-20, 20), -math.Rand(70, 150)
          m.max = math.Rand(0.9, 1.8)
          m.size = math.Rand(4, 10)
     else
          -- donma: dört kenara yakın, yavaşça süzülen parıltı
          local kenar = math.random(1, 4)
          local d = math.Rand(0, 30 + lvl * 50)
          if (kenar == 1) then m.x, m.y = math.Rand(0, w), d
          elseif (kenar == 2) then m.x, m.y = math.Rand(0, w), h - d
          elseif (kenar == 3) then m.x, m.y = d, math.Rand(0, h)
          else m.x, m.y = w - d, math.Rand(0, h) end
          m.vx, m.vy = math.Rand(-10, 10), math.Rand(4, 16)
          m.max = math.Rand(1.6, 3)
          m.size = math.Rand(4, 9)
     end

     motes[#motes + 1] = m
end

local SPAWN_HIZI = {zehir = 16, kanama = 7, yanma = 34, donma = 18}

local renkDamla = Color(105, 4, 8, 220)

local function MoteCiz(dt, t)
     if (#motes == 0) then return end

     surface.SetMaterial(glow)

     for i = #motes, 1, -1 do
          local m = motes[i]
          m.life = m.life + dt

          if (m.life >= m.max) then
               table.remove(motes, i)
          else
               local a = aktif[m.etki]
               local lvl = a and a.level or 0
               local col = Renk(m.etki)

               if (m.ay) then m.vy = m.vy + m.ay * dt end
               m.x = m.x + m.vx * dt
               m.y = m.y + m.vy * dt

               local f = m.life / m.max
               local fade = math.min(f / 0.15, 1) * math.min((1 - f) / 0.3, 1) * math.max(lvl, 0.15)
               local s = m.size
               local x = m.x
               local y = m.y

               if (m.etki == "zehir") then
                    x = x + math.sin(m.life * 4 + m.seed) * 6
                    s = s * (1 + f * 0.4)
                    surface.SetDrawColor(col.r, col.g, col.b, 170 * fade)
                    surface.DrawTexturedRect(x - s, y - s, s * 2, s * 2)
                    surface.SetDrawColor(220, 255, 200, 110 * fade)
                    surface.DrawTexturedRect(x - s * 0.3 - s * 0.25, y - s * 0.3 - s * 0.25, s * 0.5, s * 0.5)
               elseif (m.etki == "kanama") then
                    -- koyu damla: parıltı dokusu additive, koyu renk onunla görünmez
                    renkDamla.a = 220 * fade
                    draw.RoundedBox(math.floor(s), x - s, y - s * 2.4, s * 2, s * 3.6, renkDamla)
                    surface.SetMaterial(glow)
                    surface.SetDrawColor(col.r, col.g * 0.3, col.b * 0.3, 70 * fade)
                    surface.DrawTexturedRect(x - s * 1.5, y - s * 1.5, s * 3, s * 3)
               elseif (m.etki == "yanma") then
                    x = x + math.sin(m.life * 9 + m.seed) * 5
                    local k = 1 - f
                    surface.SetDrawColor(col.r, col.g * (0.6 + k * 0.4), col.b, 210 * fade)
                    surface.DrawTexturedRect(x - s, y - s, s * 2, s * 2)
                    surface.SetDrawColor(255, 230, 150, 160 * fade * k)
                    surface.DrawTexturedRect(x - s * 0.3, y - s * 0.3, s * 0.6, s * 0.6)
               else
                    local p = 0.6 + math.sin(t * 6 + m.seed) * 0.4
                    surface.SetDrawColor(col.r, col.g, col.b, 150 * fade)
                    surface.DrawTexturedRect(x - s, y - s, s * 2, s * 2)
                    surface.SetDrawColor(255, 255, 255, 200 * fade * p)
                    surface.DrawTexturedRect(x - s * 0.25, y - s * 0.25, s * 0.5, s * 0.5)
               end
          end
     end
end

/*
*   elektrik yayları
*/

local function YayEkle(w, h)
     local kenar = math.random(1, 4)
     local x, y, dx, dy

     if (kenar == 1) then x, y, dx, dy = math.Rand(0, w), 0, 0, 1
     elseif (kenar == 2) then x, y, dx, dy = math.Rand(0, w), h, 0, -1
     elseif (kenar == 3) then x, y, dx, dy = 0, math.Rand(0, h), 1, 0
     else x, y, dx, dy = w, math.Rand(0, h), -1, 0 end

     local noktalar = {x, y}
     local boy = math.Rand(70, 200)
     local adim = 8

     for i = 1, adim do
          local ilerle = boy / adim
          local sapma = math.Rand(-22, 22)
          x = x + dx * ilerle + dy * sapma
          y = y + dy * ilerle + dx * sapma
          noktalar[#noktalar + 1] = x
          noktalar[#noktalar + 1] = y
     end

     arcs[#arcs + 1] = {n = noktalar, life = 0, max = math.Rand(0.08, 0.18)}
end

local function YayCiz(dt, col)
     for i = #arcs, 1, -1 do
          local a = arcs[i]
          a.life = a.life + dt

          if (a.life >= a.max) then
               table.remove(arcs, i)
          else
               local f = 1 - a.life / a.max
               local n = a.n

               for k = 1, #n - 3, 2 do
                    local x1, y1, x2, y2 = n[k], n[k + 1], n[k + 2], n[k + 3]
                    surface.SetDrawColor(col.r, col.g, col.b, 200 * f)
                    surface.DrawLine(x1 - 1, y1, x2 - 1, y2)
                    surface.DrawLine(x1 + 1, y1, x2 + 1, y2)
                    surface.DrawLine(x1, y1 - 1, x2, y2 - 1)
                    surface.SetDrawColor(255, 255, 255, 255 * f)
                    surface.DrawLine(x1, y1, x2, y2)
               end
          end
     end
end

/*
*   kenar katmanları
*/

local SERIT = 32

-- dalgalı kenar şeridi, köşelere doğru incelir (kenetleşme efektindekiyle aynı)
local function DalgaKenar(mat, kenar, w, h, kalin, t, faz)
     surface.SetMaterial(mat)

     local uzun = (kenar <= 2) and w or h
     local adim = uzun / SERIT

     for i = 0, SERIT - 1 do
          local u = (i + 0.5) / SERIT
          local dalga = 0.55 + math.sin(t * 1.7 + u * 9 + faz) * 0.25 + math.sin(t * 2.9 - u * 15 + faz * 2) * 0.2
          local th = kalin * dalga * math.sin(u * math.pi) ^ 0.6

          if (th > 1) then
               local p = math.floor(i * adim)
               local q = math.floor((i + 1) * adim) - p + 1

               if (kenar == 1) then surface.DrawTexturedRect(p, 0, q, th)
               elseif (kenar == 2) then surface.DrawTexturedRect(p, h - th, q, th)
               elseif (kenar == 3) then surface.DrawTexturedRect(0, p, th, q)
               else surface.DrawTexturedRect(w - th, p, th, q) end
          end
     end
end

-- kalp atışı: "güm-güm" çift vuruş
local function Nabiz(beat)
     return math.exp(-((beat - 0.05) / 0.06) ^ 2) + 0.55 * math.exp(-((beat - 0.27) / 0.07) ^ 2)
end

local NABIZ = {zehir = 0.5, kanama = 1, yanma = 0.6, donma = 0.25, elektrik = 0.4}
local BPM = {zehir = 80, kanama = 110, yanma = 100, donma = 55, elektrik = 95}

local function KatmanCiz(etki, a, w, h, t, dt)
     local lvl = a.level
     local col = Renk(etki)
     local kisa = math.min(w, h)
     local darbe = math.exp(-(t - a.darbe) * 3)

     a.beat = (a.beat + dt * (BPM[etki] or 80) / 60) % 1
     local hb = Nabiz(a.beat) * (NABIZ[etki] or 0.5)

     local vinyet = Doku("vinyet")
     local damar = Doku("damar")

     -- yeni vuruşta tek kare renk parlaması
     if (darbe > 0.02) then
          surface.SetDrawColor(col.r, col.g, col.b, 45 * darbe * lvl)
          surface.DrawRect(0, 0, w, h)
     end

     if (vinyet) then
          local function Vinyet(ek, r, g, b, alfa)
               local m = (1 - lvl) * kisa * 0.2 + ek - hb * 10 - darbe * 18
               local ox, oy = math.sin(t * 0.8) * 6, math.cos(t * 0.6) * 5
               surface.SetMaterial(vinyet)
               surface.SetDrawColor(r, g, b, alfa)
               surface.DrawTexturedRect(-m + ox, -m + oy, w + m * 2, h + m * 2)
          end

          Vinyet(0, col.r * 0.25, col.g * 0.25, col.b * 0.3, lvl * 140 * (0.85 + hb * 0.15))
          Vinyet(26 + math.sin(t * 1.3) * 8, col.r, col.g, col.b, lvl * 95 * (0.6 + hb * 0.4))
     end

     -- damarlar: zehirde yeşil damar, kanamada kılcal, donmada buz çatlağı
     if (damar and etki != "elektrik") then
          local dl = lvl * (etki == "yanma" and 0.45 or 1)
          local m = (1 - dl) * kisa * 0.16 - hb * 6 - darbe * 10
          surface.SetMaterial(damar)

          if (etki == "donma") then
               surface.SetDrawColor(220, 240, 255, dl * 150)
          else
               surface.SetDrawColor(math.min(255, col.r + 40), math.min(255, col.g + 40), math.min(255, col.b + 40), dl * 130 * (0.45 + hb * 0.55))
          end

          surface.DrawTexturedRect(-m, -m, w + m * 2, h + m * 2)
     end

     -- dalgalı kenar ışığı
     local yumusak = vinyet and 0.55 or 1
     local alfa = math.min(130, 30 + lvl * 90) * yumusak * (0.8 + hb * 0.2 + darbe * 0.4)
     local kalin = kisa * (0.04 + lvl * 0.05) * (vinyet and 0.75 or 1)

     if (etki == "yanma") then
          -- alevde alt kenar daha kalın ve titrek
          surface.SetDrawColor(col.r, col.g, col.b, alfa)
          DalgaKenar(gradD, 2, w, h, kalin * (1.6 + math.sin(t * 13) * 0.15), t * 2.2, 1.7)
          DalgaKenar(gradL, 3, w, h, kalin * 0.8, t * 2.2, 3.1)
          DalgaKenar(gradR, 4, w, h, kalin * 0.8, t * 2.2, 4.6)
          DalgaKenar(gradU, 1, w, h, kalin * 0.5, t * 2.2, 0)
     elseif (etki == "elektrik") then
          -- şimşekte kenar ışığı kesik kesik yanar
          local cak = (math.sin(t * 37) > 0.2 or darbe > 0.3) and 1 or 0.25
          surface.SetDrawColor(col.r, col.g, col.b, alfa * cak)
          DalgaKenar(gradU, 1, w, h, kalin, t * 3, 0)
          DalgaKenar(gradD, 2, w, h, kalin, t * 3, 1.7)
          DalgaKenar(gradL, 3, w, h, kalin, t * 3, 3.1)
          DalgaKenar(gradR, 4, w, h, kalin, t * 3, 4.6)
     else
          surface.SetDrawColor(col.r, col.g, col.b, alfa)
          DalgaKenar(gradU, 1, w, h, kalin, t, 0)
          DalgaKenar(gradD, 2, w, h, kalin, t, 1.7)
          DalgaKenar(gradL, 3, w, h, kalin, t, 3.1)
          DalgaKenar(gradR, 4, w, h, kalin, t, 4.6)
     end

     -- parçacık üretimi (yalnızca etki sürerken)
     if (a.bitis > t) then
          if (etki == "elektrik") then
               if (t >= (a.yay or 0)) then
                    a.yay = t + math.Rand(0.06, 0.3) * (1.4 - lvl * 0.6)
                    YayEkle(w, h)
                    if (math.random() < 0.35) then a.darbe = math.max(a.darbe, t - 0.35) end
               end
          else
               a.spawn = (a.spawn or 0) + dt * (SPAWN_HIZI[etki] or 10) * (0.4 + lvl * 0.6)
               while (a.spawn >= 1) do
                    a.spawn = a.spawn - 1
                    MoteEkle(etki, w, h, lvl)
               end
          end
     end
end

/*
*   etki yazısı: ekranın üstünde, kalan süre çubuğuyla
*/

local function YaziCiz(w, h, t)
     local y = math.floor(h * 0.12)

     for etki, a in SortedPairs(aktif) do
          local kalan = a.bitis - t

          if (kalan > 0) then
               local tanim = SardonHayvan.Etkiler[etki]
               local col = Renk(etki)
               local frac = math.Clamp(kalan / (SardonHayvan.EtkiSure or 7), 0, 1)
               local alfa = math.min(a.level * 1.4, 1)
               local darbe = math.exp(-(t - a.darbe) * 4)

               local gen, yuk = 220, 34
               local x = math.floor(w * 0.5 - gen * 0.5)

               surface.SetAlphaMultiplier(alfa)
                    surface.SetDrawColor(renkArka)
                    surface.DrawRect(x, y, gen, yuk)
                    surface.SetDrawColor(col.r, col.g, col.b, 220)
                    surface.DrawRect(x, y + yuk - 3, gen * frac, 3)
                    surface.SetDrawColor(col.r, col.g, col.b, 90 + darbe * 165)
                    surface.DrawOutlinedRect(x, y, gen, yuk)

                    draw.SimpleText(tanim and tanim.ad or etki, "SardonHayvan.Etki", x + 12 + 1, y + yuk * 0.5 + 1, renkGolge, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                    draw.SimpleText(tanim and tanim.ad or etki, "SardonHayvan.Etki", x + 12, y + yuk * 0.5, renkYazi, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                    draw.SimpleText(string.format("%.1f", kalan), "SardonHayvan.EtkiSn", x + gen - 12, y + yuk * 0.5, col, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
               surface.SetAlphaMultiplier(1)

               y = y + yuk + 6
          end
     end
end

/*
*   hook'lar
*/

local function Kaldir()
     hooklu = false
     hook.Remove("HUDPaint", "SardonHayvan.Etki")
     hook.Remove("RenderScreenspaceEffects", "SardonHayvan.Etki")
end

local function Ciz()
     local w, h = ScrW(), ScrH()
     local t = CurTime()
     local dt = FrameTime()
     local bos = true

     for etki, a in pairs(aktif) do
          -- son 1.2 sn'de söner; yeni vuruş hızlıca geri yakar
          local hedef = math.Clamp((a.bitis - t) / 1.2, 0, 1)
          a.level = math.Approach(a.level, hedef, dt * (hedef > a.level and 3 or 1.5))

          if (a.level <= 0 and a.bitis <= t) then
               aktif[etki] = nil
          else
               bos = false
               KatmanCiz(etki, a, w, h, t, dt)
          end
     end

     MoteCiz(dt, t)

     if (#arcs > 0) then
          YayCiz(dt, Renk("elektrik"))
     end

     YaziCiz(w, h, t)

     if (bos and #motes == 0 and #arcs == 0) then
          Kaldir()
     end
end

-- etkiye göre hafif renk kayması (zehir yeşile, yanma sıcağa, donma/kanama soluğa)
local function RenkKaydir()
     local rr, rg, rb = 0, 0, 0
     local renk, kontrast = 1, 1

     for etki, a in pairs(aktif) do
          local l = a.level

          if (etki == "zehir") then
               local p = 0.75 + math.sin(CurTime() * 2) * 0.25
               rr, rg, rb = rr - 0.02 * l, rg + 0.05 * l * p, rb - 0.02 * l
               renk = renk - 0.15 * l
          elseif (etki == "kanama") then
               rr = rr + 0.03 * l
               renk = renk - 0.3 * l
          elseif (etki == "yanma") then
               rr, rg, rb = rr + 0.04 * l, rg + 0.015 * l, rb - 0.03 * l
               kontrast = kontrast + 0.06 * l
          elseif (etki == "donma") then
               rr, rg, rb = rr - 0.02 * l, rg + 0.01 * l, rb + 0.05 * l
               renk = renk - 0.35 * l
          end
     end

     if (rr == 0 and rg == 0 and rb == 0 and renk == 1 and kontrast == 1) then return end

     DrawColorModify({
          ["$pp_colour_addr"] = rr,
          ["$pp_colour_addg"] = rg,
          ["$pp_colour_addb"] = rb,
          ["$pp_colour_brightness"] = 0,
          ["$pp_colour_contrast"] = kontrast,
          ["$pp_colour_colour"] = math.max(renk, 0.3),
          ["$pp_colour_mulr"] = 0,
          ["$pp_colour_mulg"] = 0,
          ["$pp_colour_mulb"] = 0
     })
end

local function Bagla()
     if (hooklu) then return end
     hooklu = true
     hook.Add("HUDPaint", "SardonHayvan.Etki", Ciz)
     hook.Add("RenderScreenspaceEffects", "SardonHayvan.Etki", RenkKaydir)
end

net.Receive("SardonHayvan.Etki", function()
     local etki = net.ReadString()
     local bitis = net.ReadFloat()

     if (etki == "") then
          -- hepsini söndür (ölüm / doğma / karakter değişimi)
          for _, a in pairs(aktif) do a.bitis = 0 end
          return
     end

     local a = aktif[etki]

     if (bitis <= 0) then
          if (a) then a.bitis = 0 end
          return
     end

     if (!a) then
          a = {level = 0, beat = 0, darbe = 0}
          aktif[etki] = a
     end

     a.bitis = bitis
     a.darbe = CurTime()

     Bagla()
end)
