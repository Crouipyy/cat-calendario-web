-- "addons\\sardonbuyuagaci\\lua\\sardon_buyuagaci\\cl_sayfa.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Büyü Ağacı :: asa menüsü (Büyü Kitabı teması) > "Büyü Ağacı" sekmesi
--
-- Sayfa HpwRewrite.Nocturne.Pages.buyuagaci olarak kaydolur; sekme düğmesi
-- [hogwarts] wand/lua/hpwrewrite/nocturne/15_kitap_menu.lua TABS listesinde.
-- Bu eklenti yoksa sekme kendiliğinden gizlenir.
--
-- Yerleşim (tasarım birimi, içerik alanı 1080 x 520, K.S ile ölçeklenir):
--   sol 236   :: Büyü Puanı kartı + ağaç listesi (bağlı Karakter Gelişimi dalı başlıkları altında)
--   sağ 830   :: başlık 58 · ağaç tuvali (kademe oluğu 92 + dal sütunları, alttan üste Temel → Feci Yorucu)
--               · ayrıntı şeridi 92 (seçili büyü, durum, "Öğren" düğmesi)
--
-- Parçacıklar tamamen 2B: tuvalde yükselen tozlar, açık dallarda akan ışık, açılabilir düğümlerin
-- çevresinde dönen kıvılcımlar, açılışta patlama + genişleyen halka. Dünyadaki efekt cl_core.lua'da.

local BA = SardonBuyuAgaci

BA.SeciliAgac = BA.SeciliAgac or nil

local glow = Material("sprites/light_glow02_add")
local hasGlow = !glow:IsError()

local LEFT_W, GAP = 236, 14
local HEAD_H, DET_H = 58, 92
local GUT_W = 92
local NODE = 44

local fontKey
local function Fontlar(K)
     local key = K.scale .. "|" .. K.FontMode()
     if (fontKey == key) then return end
     fontKey = key

     local serif = K.FontMode() == "magaza" and K.SHOP_FONT or "Georgia"
     local sans = K.FontMode() == "kitap" and "Tahoma" or K.SHOP_FONT

     surface.CreateFont("sba.puan", {font = serif, size = math.max(16, math.floor(40 * K.scale)), weight = 400, extended = true, antialias = true})
     surface.CreateFont("sba.roma", {font = serif, size = math.max(10, math.floor(17 * K.scale)), weight = 400, extended = true, antialias = true})
     surface.CreateFont("sba.bas", {font = serif, size = math.max(12, math.floor(22 * K.scale)), weight = 400, extended = true, antialias = true})
     surface.CreateFont("sba.harf", {font = serif, size = math.max(10, math.floor(18 * K.scale)), weight = 400, extended = true, antialias = true})
     surface.CreateFont("sba.rozet", {font = sans, size = math.max(8, math.floor(10 * K.scale)), weight = 600, extended = true, antialias = true})
end

local function Yaz(str, font, x, y, c, ax, ay)
     return draw.SimpleText(str, font, x, y, c, ax, ay)
end

local function TW(str, font)
     surface.SetFont(font)
     return (surface.GetTextSize(tostring(str or "")))
end

local function IlkHarf(str)
     return string.match(str or "", "^[%z\1-\127\194-\244][\128-\191]*") or ""
end

-- kalın çizgi (dörtgen)
local function Kalin(x1, y1, x2, y2, t, c)
     local dx, dy = x2 - x1, y2 - y1
     local len = math.sqrt(dx * dx + dy * dy)
     if (len < 1) then return end
     local nx, ny = -dy / len * t / 2, dx / len * t / 2

     draw.NoTexture()
     surface.SetDrawColor(c.r, c.g, c.b, c.a or 255)
     surface.DrawPoly({
          {x = x1 + nx, y = y1 + ny},
          {x = x2 + nx, y = y2 + ny},
          {x = x2 - nx, y = y2 - ny},
          {x = x1 - nx, y = y1 - ny}
     })
end

local function Isik(x, y, r, c, a)
     if (!hasGlow) then return end
     surface.SetMaterial(glow)
     surface.SetDrawColor(c.r, c.g, c.b, a)
     surface.DrawTexturedRect(x - r, y - r, r * 2, r * 2)
end

-- asma kilit
local function Kilit(K, cx, cy, s, c)
     K.Box(cx - s * 0.55, cy - s * 0.05, s * 1.1, s * 0.8, c)
     surface.SetDrawColor(c.r, c.g, c.b, c.a or 255)
     local r = s * 0.36
     local px, py
     for i = 0, 8 do
          local a = math.pi + i / 8 * math.pi
          local x, y = cx + math.cos(a) * r, cy - s * 0.05 + math.sin(a) * r
          if (px) then surface.DrawLine(px, py, x, y) surface.DrawLine(px + 1, py, x + 1, y) end
          px, py = x, y
     end
end

local function RenkKarisim(a, b, f)
     return Color(a.r + (b.r - a.r) * f, a.g + (b.g - a.g) * f, a.b + (b.b - a.b) * f, (a.a or 255) + ((b.a or 255) - (a.a or 255)) * f)
end

local ACIK = {biliniyor = true, yeniden = true}

/*
*   ------------------------------------------------------------------
*   sayfa
*   ------------------------------------------------------------------
*/

local function Build(ctx)
     local N = HpwRewrite.Nocturne
     local K = N.Kitap
     local C = K.C
     local S = K.S
     local P = ctx.panel
     local W, H = ctx.w, ctx.h
     local ply = LocalPlayer()

     Fontlar(K)

     if (!BA.AyarGeldi and BA.AyarIste) then BA.AyarIste() end

     local MX = LEFT_W + GAP
     local MW = W - MX
     local CAN_Y = HEAD_H + 4
     local CAN_H = H - CAN_Y - DET_H - 8

     local st = {
          agac = (BA.SeciliAgac and BA.Agac(BA.SeciliAgac)) and BA.SeciliAgac or BA.Agaclar[1].id,
          cache = nil, cacheAt = 0,
          acilis = RealTime(),
          kivilcim = {}, halka = {}, toz = {},
          sonTik = 0
     }

     local function Char() return IsValid(ply) and ply:GetCharacter() or nil end
     local function Agac() return BA.Agac(st.agac) end

     local function Durumlar()
          if (st.cache and RealTime() < st.cacheAt) then return st.cache end
          st.cacheAt = RealTime() + 0.5

          local char = Char()
          local agac = Agac()
          local c = {dugum = {}, kademe = {}, ilerleme = {}, puan = BA.Puan(char), k = BA.Kazanilan(char), h = BA.Harcanan(char)}

          for i = 1, #BA.Kademeler do
               local ok, sebep = BA.KademeAcik(char, agac, i)
               c.kademe[i] = {ok = ok, sebep = sebep}
          end

          for _, d in ipairs(agac.dugumler) do
               local durum, sebep = BA.Durum(ply, char, d.buyu)
               c.dugum[d.buyu] = {durum = durum, sebep = sebep}
          end

          for _, a in ipairs(BA.Agaclar) do
               local x, y = BA.AgacIlerleme(ply, char, a)
               c.ilerleme[a.id] = {x, y}
          end

          st.cache = c
          return c
     end

     local function Gecersiz() st.cacheAt = 0 end

     local function AgacSec(id)
          if (st.agac == id) then return end
          st.agac = id
          BA.SeciliAgac = id
          st.secili, st.hover, st.hoverKademe, st.onay = nil, nil, nil, nil
          st.yer = nil
          st.acilis = RealTime()
          st.toz = {}
          Gecersiz()
     end

     /*
     *   sol :: puan kartı
     */

     local kart = vgui.Create("DPanel", P)
     kart:SetPos(0, 0)
     kart:SetSize(S(LEFT_W), S(92))
     kart.Paint = function(s, w, h)
          local c = Durumlar()
          local now = RealTime()

          K.Box(0, 0, w, h, Color(10, 16, 13, 220))
          K.Outline(0, 0, w, h, C.detailLine)

          K.Spaced("BÜYÜ PUANI", "sans8", S(14), S(12), C.eyebrow, S(2))

          local px, py = S(14), S(26)
          local tw = TW(c.puan, "sba.puan")
          Isik(px + tw / 2, py + S(22), S(46), C.gold, 70 + math.sin(now * 2) * 25)
          Yaz(tostring(c.puan), "sba.puan", px, py, C.ivoryHi)

          for i = 0, 2 do
               local a = now * 0.9 + i * 2.1
               K.Sparkle(px + tw + S(14) + math.cos(a) * S(6), py + S(20) + math.sin(a * 1.3) * S(8), S(3 + i), ColorAlpha(C.gold, 120 + 80 * math.sin(a * 2)))
          end

          K.Text("kazanılan " .. c.k .. "  ·  harcanan " .. c.h, "sans9", S(14), h - S(14), C.hint, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
          K.Text("Derslerden kazanılır", "sans9", w - S(12), S(16), C.studentSm, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
     end

     /*
     *   sol :: ağaç listesi
     */

     local LIST_Y = 100
     local BAS_H = 15 -- gelişim dalı başlığı

     -- Ağaçlar bağlı oldukları Karakter Gelişimi dalının başlığı altında durur.
     -- {{bas = grup} | {agac = ağaç}, y, h}
     local function ListeSatirlari(h)
          local gruplar = BA.Gruplar()
          local bh = S(BAS_H)
          local rh = (h - #gruplar * bh) / math.max(1, #BA.Agaclar)
          local out, y = {}, 0

          for _, g in ipairs(gruplar) do
               out[#out + 1] = {bas = g, y = y, h = bh}
               y = y + bh
               for _, a in ipairs(g.agaclar) do
                    out[#out + 1] = {agac = a, y = y, h = rh}
                    y = y + rh
               end
          end
          return out
     end

     local liste = vgui.Create("DPanel", P)
     liste:SetPos(0, S(LIST_Y))
     liste:SetSize(S(LEFT_W), S(H - LIST_Y))
     liste:SetCursor("hand")
     liste.Paint = function(s, w, h)
          local c = Durumlar()
          local satirlar = ListeSatirlari(h)
          local mx, my = s:CursorPos()
          local hov

          K.Box(0, 0, w, h, Color(10, 16, 13, 160))
          K.Outline(0, 0, w, h, C.detailLine)

          for _, r in ipairs(satirlar) do
               local y, rh = r.y, r.h

               if (r.bas) then
                    K.Box(0, y, w, rh, Color(0, 0, 0, 90))
                    K.Box(0, y + rh - 1, w, 1, Color(156, 128, 80, 46))
                    K.Diamond(S(11), y + rh / 2, S(2.5), C.seal, true)
                    K.Spaced(K.Upper(r.bas.ad), "sans8", S(19), y + rh / 2 - S(5), C.eyebrow, S(1.5))
               else
                    local a = r.agac
                    local on = a.id == st.agac
                    if (s:IsHovered() and my >= y and my < y + rh) then hov = a end

                    if (on) then
                         if (!K.Slice3("row_selected", 0, y, w, rh, 24)) then K.Box(0, y, w, rh, Color(99, 43, 40, 120)) end
                         K.Box(0, y, S(2), rh, a.renk)
                    elseif (hov == a) then
                         K.Box(0, y, w, rh, C.navHover)
                    end

                    local es = math.min(rh - S(4), S(20))
                    K.Tex(a.arma, S(14), y + (rh - es) / 2, es, es, on and C.white or Color(255, 255, 255, 190))

                    local tx = S(14) + es + S(8)
                    K.Text(a.ad, "serif13", tx, y + rh / 2 - S(1), on and C.rowTextSel or C.rowText, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

                    local il = c.ilerleme[a.id] or {0, 0}
                    local frac = il[2] > 0 and il[1] / il[2] or 0
                    K.Text(il[1] .. "/" .. il[2], "sans9", w - S(10), y + rh / 2, frac >= 1 and C.ready or C.rowMeta, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

                    -- ilerleme: satırın alt kenarında ince şerit
                    local bw = w - tx - S(10)
                    K.Box(tx, y + rh - S(3), bw, S(2), C.progTrack)
                    K.Box(tx, y + rh - S(3), bw * frac, S(2), on and a.renk or ColorAlpha(a.renk, 170))
               end
          end

          s.Hov = hov
     end
     liste.OnMousePressed = function(s, code)
          if (code != MOUSE_LEFT or !s.Hov) then return end
          local a = s.Hov
          if (a.id != st.agac) then
               N.SndClick()
               AgacSec(a.id)
          end
     end
     liste.OnCursorMoved = function(s)
          local prev = s.HovSnd
          if (s.Hov != prev) then
               s.HovSnd = s.Hov
               if (s.Hov) then N.SndHover() end
          end
     end

     /*
     *   sağ :: başlık
     */

     local bas = vgui.Create("DPanel", P)
     bas:SetPos(S(MX), 0)
     bas:SetSize(S(MW), S(HEAD_H))
     bas.Paint = function(s, w, h)
          local a = Agac()
          local c = Durumlar()
          local es = S(48)

          Isik(es / 2, h / 2, S(40), a.renk, 50)
          K.Tex(a.arma, 0, (h - es) / 2, es, es)

          local tx = es + S(12)
          Yaz(a.ad, "sba.bas", tx, S(6), C.heading)
          K.Spaced(a.ust or "", "sans8", tx + S(1), S(36), C.eyebrow, S(2))

          -- sağ: bağlı gelişim dalı + kademe özeti
          local G = SardonGelisim
          local katId = BA.GelisimBag(a)
          local kat = G and G.KategoriBul and G.KategoriBul(katId)
          local rol, tavan = BA.RolTavani(ply:GetCharacter(), a)
          local rolYazi = rol and ("  ·  " .. BA.RolAdlari[rol] .. ", en fazla " .. BA.Kademeler[tavan].kisa) or ""
          K.Text("Kademe kilidi: Karakter Gelişimi › " .. (kat and kat.ad or katId) .. rolYazi, "sans9", w, S(14), C.hint, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

          local x = w
          for i = #BA.Kademeler, 1, -1 do
               local ok = c.kademe[i] and c.kademe[i].ok
               local lbl = BA.Kademeler[i].roma
               local pw = S(26)
               x = x - pw
               K.Box(x, S(28), pw - S(4), S(20), ok and Color(174, 186, 152, 26) or Color(0, 0, 0, 90))
               K.Outline(x, S(28), pw - S(4), S(20), ok and Color(174, 186, 152, 85) or C.closeLine)
               K.Text(lbl, "sans9", x + (pw - S(4)) / 2, S(38), ok and C.ready or C.studentSm, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
          end

          K.Box(0, h - 1, w, 1, C.navLine)
     end

     /*
     *   sağ :: tuval
     */

     local tuval = vgui.Create("DPanel", P)
     tuval:SetPos(S(MX), S(CAN_Y))
     tuval:SetSize(S(MW), S(CAN_H))
     tuval:SetCursor("arrow")

     local function Yerlesim(cw, ch)
          local key = st.agac .. ":" .. cw .. "x" .. ch
          if (st.yer and st.yerKey == key) then return st.yer end

          local agac = Agac()
          local gut = S(GUT_W)
          local top, bot = S(30), S(8)
          local nDal = #agac.dallar
          local colW = (cw - gut - S(8)) / nDal
          local rh = (ch - top - bot) / #BA.Kademeler

          local hucre = {}
          for _, d in ipairs(agac.dugumler) do
               local k = d.dal .. ":" .. d.kademe
               hucre[k] = hucre[k] or {}
               table.insert(hucre[k], d)
          end

          local pos = {}
          local adim = math.min(S(64), colW / 3)
          for _, list in pairs(hucre) do
               for i, d in ipairs(list) do
                    pos[d.buyu] = {
                         x = gut + (d.dal - 0.5) * colW + (i - (#list + 1) / 2) * adim,
                         y = top + (#BA.Kademeler - d.kademe + 0.5) * rh
                    }
               end
          end

          st.yer = {pos = pos, gut = gut, top = top, bot = bot, colW = colW, rh = rh}
          st.yerKey = key
          return st.yer
     end

     local function Patlat(buyu, renk)
          local y = st.yer and st.yer.pos[buyu]
          if (!y) then return end

          for i = 1, 64 do
               local a = math.Rand(0, math.pi * 2)
               local v = math.Rand(S(60), S(240))
               st.kivilcim[#st.kivilcim + 1] = {
                    x = y.x, y = y.y, vx = math.cos(a) * v, vy = math.sin(a) * v,
                    omur = math.Rand(0.6, 1.4), yas = 0, boy = math.Rand(S(5), S(14)),
                    renk = (i % 3 == 0) and C.ivoryHi or renk
               }
          end

          st.halka[#st.halka + 1] = {x = y.x, y = y.y, yas = 0, omur = 0.8, renk = renk}
          st.halka[#st.halka + 1] = {x = y.x, y = y.y, yas = -0.15, omur = 0.9, renk = C.ivoryHi}
     end

     tuval.Think = function(s)
          local w, h = s:GetSize()
          local yer = Yerlesim(w, h)
          local mx, my = s:CursorPos()
          local hov, hovK

          if (s:IsHovered()) then
               local r = S(NODE) / 2 + S(4)
               for buyu, p in pairs(yer.pos) do
                    if ((mx - p.x) ^ 2 + (my - p.y) ^ 2 <= r * r) then hov = buyu break end
               end

               if (!hov and mx < yer.gut and my > yer.top and my < h - yer.bot) then
                    hovK = #BA.Kademeler - math.floor((my - yer.top) / yer.rh)
                    if (hovK < 1 or hovK > #BA.Kademeler) then hovK = nil end
               end
          end

          if (hov != st.hover) then
               st.hover = hov
               if (hov) then N.SndHover() end
          end
          st.hoverKademe = hovK
          s:SetCursor(hov and "hand" or "arrow")
     end

     tuval.OnMousePressed = function(s, code)
          if (code != MOUSE_LEFT) then return end

          if (st.hover) then
               local now = RealTime()
               if (st.secili == st.hover and now - st.sonTik < 0.35) then
                    st.sonTik = 0
                    if (st.AcDene) then st.AcDene(true) end
                    return
               end

               st.sonTik = now
               if (st.secili != st.hover) then
                    st.secili = st.hover
                    st.onay = nil
                    N.SndClick()
               end
          else
               st.secili = nil
               st.onay = nil
          end
     end

     tuval.Paint = function(s, w, h)
          local agac = Agac()
          local c = Durumlar()
          local yer = Yerlesim(w, h)
          local now = RealTime()
          local ft = FrameTime()
          local renk = agac.renk
          local ns = S(NODE)

          /*
          *   zemin :: gök levhası (S arması + yıldızlar) soluk, kenarlar karartılmış
          */

          K.Box(0, 0, w, h, Color(7, 12, 10, 240))

          local plate = K.Mat("celestial_plate_s")
          if (plate) then
               surface.SetMaterial(plate)
               surface.SetDrawColor(255, 255, 255, 46)
               local v0 = 0.02
               local v1 = v0 + (h / w) * 0.5 * 0.9
               surface.DrawTexturedRectUV(0, 0, w, h, 0, v0, 1, math.min(1, v1))
          end

          Isik(w * 0.62, h * 0.18, w * 0.42, renk, 16)
          K.VGradient(0, 0, w, S(40), {{0, Color(5, 9, 7, 200)}, {1, Color(5, 9, 7, 0)}})
          K.VGradient(0, h - S(50), w, S(50), {{0, Color(5, 9, 7, 0)}, {1, Color(5, 9, 7, 210)}})

          /*
          *   kademe bantları ve oluk
          */

          for i = 1, #BA.Kademeler do
               local y = yer.top + (#BA.Kademeler - i) * yer.rh
               local kd = c.kademe[i]
               local hov = st.hoverKademe == i

               if (kd and !kd.ok) then
                    K.Box(yer.gut, y, w - yer.gut, yer.rh, Color(0, 0, 0, 70))
                    for hx = yer.gut, w, S(22) do
                         K.Line(hx, y + yer.rh, hx + S(14), y, Color(0, 0, 0, 34))
                    end
               end

               if (hov) then K.Box(0, y, w, yer.rh, Color(161, 132, 79, 14)) end
               K.Box(S(10), y, w - S(20), 1, Color(156, 128, 80, 26))

               local ok = kd and kd.ok
               local cy = y + yer.rh / 2
               Yaz(BA.Kademeler[i].roma, "sba.roma", S(14), cy - S(6), ok and C.gold or C.studentSm, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
               K.Spaced(K.Upper(BA.Kademeler[i].kisa), "sans8", S(14), cy + S(5), ok and C.eyebrow or C.studentSm, S(1))

               local rw = TW(BA.Kademeler[i].roma, "sba.roma")
               if (ok) then
                    K.Check(S(14) + rw + S(8), cy - S(12), S(10), C.ready)
               else
                    Kilit(K, S(14) + rw + S(13), cy - S(7), S(9), C.close)
               end
          end
          K.Box(yer.gut - S(4), yer.top, 1, h - yer.top - yer.bot, Color(156, 128, 80, 40))

          /*
          *   dal başlıkları
          */

          for i, dal in ipairs(agac.dallar) do
               local cx = yer.gut + (i - 0.5) * yer.colW
               local up = K.Upper(dal)
               local tw = K.SpacedW(up, "sans8", S(2))
               K.Spaced(up, "sans8", cx, S(10), C.eyebrow, S(2), TEXT_ALIGN_CENTER)
               -- süs çizgileri sütuna sığdığı kadar (4 dallı ağaçta kısalır)
               local sus = math.min(S(24), (yer.colW - tw) / 2 - S(22))
               if (sus > S(6)) then
                    K.Box(cx - tw / 2 - S(10) - sus, S(15), sus, 1, Color(156, 128, 80, 70))
                    K.Box(cx + tw / 2 + S(10), S(15), sus, 1, Color(156, 128, 80, 70))
                    K.Diamond(cx - tw / 2 - S(16) - sus, S(15), S(3), C.seal, true)
                    K.Diamond(cx + tw / 2 + S(16) + sus, S(15), S(3), C.seal, true)
               end

               if (i > 1) then
                    local x = yer.gut + (i - 1) * yer.colW
                    for yy = yer.top, h - yer.bot, S(8) do K.Box(x, yy, 1, S(3), Color(156, 128, 80, 20)) end
               end
          end

          /*
          *   yükselen tozlar
          */

          while (#st.toz < 34) do
               st.toz[#st.toz + 1] = {
                    x = math.Rand(yer.gut, w), y = math.Rand(yer.top, h + S(10)),
                    vy = -math.Rand(S(6), S(22)), sal = math.Rand(0, 6.28), boy = math.Rand(S(2), S(6)),
                    omur = math.Rand(4, 9), yas = math.Rand(0, 4)
               }
          end
          for i = #st.toz, 1, -1 do
               local t = st.toz[i]
               t.yas = t.yas + ft
               t.y = t.y + t.vy * ft
               t.x = t.x + math.sin(now * 0.8 + t.sal) * S(6) * ft
               if (t.yas > t.omur or t.y < yer.top - S(10)) then
                    table.remove(st.toz, i)
               else
                    local f = math.sin(math.Clamp(t.yas / t.omur, 0, 1) * math.pi)
                    Isik(t.x, t.y, t.boy * 2.2, renk, 90 * f)
               end
          end

          /*
          *   bağlantılar
          */

          for _, d in ipairs(agac.dugumler) do
               local p2 = yer.pos[d.buyu]
               local s2 = c.dugum[d.buyu] and c.dugum[d.buyu].durum
               for gi, g in ipairs(d.gerek) do
                    local p1 = yer.pos[g]
                    local s1 = c.dugum[g] and c.dugum[g].durum
                    if (p1 and p2) then
                         local dx, dy = p2.x - p1.x, p2.y - p1.y
                         local len = math.sqrt(dx * dx + dy * dy)
                         local ux, uy = dx / len, dy / len
                         local r = ns / 2 + S(2)
                         local ax, ay = p1.x + ux * r, p1.y + uy * r
                         local bx, by = p2.x - ux * r, p2.y - uy * r

                         if (ACIK[s1] and ACIK[s2]) then
                              Kalin(ax, ay, bx, by, S(3), ColorAlpha(renk, 70))
                              Kalin(ax, ay, bx, by, math.max(1, S(1.4)), ColorAlpha(renk, 230))
                              -- akan ışık
                              for k = 0, 2 do
                                   local f = (now * 0.45 + k / 3 + gi * 0.17) % 1
                                   Isik(ax + (bx - ax) * f, ay + (by - ay) * f, S(7), renk, 200 * math.sin(f * math.pi))
                              end
                         elseif (ACIK[s1]) then
                              -- kesik, ilerleyen altın çizgi
                              local seg = S(8)
                              local n = math.floor(len / seg)
                              local off = (now * 2) % 1
                              for k = 0, n - 1, 2 do
                                   local f1 = math.Clamp((k + off) * seg / len, 0, 1)
                                   local f2 = math.Clamp((k + 1 + off) * seg / len, 0, 1)
                                   Kalin(ax + (bx - ax) * f1, ay + (by - ay) * f1, ax + (bx - ax) * f2, ay + (by - ay) * f2, math.max(1, S(1.4)), Color(214, 183, 120, 150))
                              end
                         else
                              Kalin(ax, ay, bx, by, 1, Color(120, 110, 90, 46))
                         end
                    end
               end
          end

          /*
          *   düğümler
          */

          for _, d in ipairs(agac.dugumler) do
               local p = yer.pos[d.buyu]
               local ds = c.dugum[d.buyu] or {}
               local durum = ds.durum
               local acik = ACIK[durum]
               local hazir = durum == "acilabilir" or durum == "yeniden"
               local kilit = durum == "kademe" or durum == "gerek"
               local hov = st.hover == d.buyu
               local sec = st.secili == d.buyu

               local gir = math.Clamp((now - st.acilis - (d.kademe - 1) * 0.06 - d.dal * 0.03) / 0.3, 0, 1)
               local sz = ns * (0.6 + 0.4 * gir) * (hov and 1.06 or 1)
               local x, y = p.x - sz / 2, p.y - sz / 2
               local al = 255 * gir

               -- hale
               if (acik) then
                    Isik(p.x, p.y, sz * 1.15, renk, 80 * gir)
               elseif (hazir) then
                    Isik(p.x, p.y, sz * (1.1 + math.sin(now * 3 + d.kademe) * 0.12), C.starOn, (90 + math.sin(now * 3) * 40) * gir)
               end
               if (hov or sec) then Isik(p.x, p.y, sz * 1.3, C.ivoryHi, 50 * gir) end

               -- yuva
               local yuvaRenk = (acik or hazir) and Color(255, 255, 255, al) or Color(170, 170, 160, 200 * gir)
               if (!K.Tex("icon_slot", x, y, sz, sz, yuvaRenk)) then
                    K.Box(x, y, sz, sz, Color(11, 19, 15, al))
               end

               -- simge
               local mat = K.SpellIcon(d.buyu)
               local ic = sz - S(10)
               if (mat) then
                    surface.SetMaterial(mat)
                    if (acik) then
                         surface.SetDrawColor(255, 255, 255, al)
                    elseif (hazir) then
                         surface.SetDrawColor(235, 228, 210, al)
                    elseif (durum == "puan") then
                         surface.SetDrawColor(190, 182, 165, 210 * gir)
                    else
                         surface.SetDrawColor(105, 105, 98, 150 * gir)
                    end
                    surface.DrawTexturedRect(p.x - ic / 2, p.y - ic / 2, ic, ic)
               else
                    Yaz(IlkHarf(d.buyu), "sba.harf", p.x, p.y, acik and C.ivoryHi or C.studentSm, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
               end

               if (kilit or durum == "kapali" or durum == "yok") then
                    K.Box(x + 2, y + 2, sz - 4, sz - 4, Color(5, 8, 6, 110 * gir))
               end

               -- çerçeve
               if (acik) then
                    K.Outline(x, y, sz, sz, ColorAlpha(renk, al))
                    K.Outline(x + 1, y + 1, sz - 2, sz - 2, ColorAlpha(renk, 120 * gir))
               elseif (hazir) then
                    local f = 0.5 + math.sin(now * 4) * 0.5
                    K.Outline(x, y, sz, sz, RenkKarisim(C.gold, C.ivoryHi, f))
               elseif (durum == "puan") then
                    K.Outline(x, y, sz, sz, Color(174, 145, 92, 120 * gir))
               end

               -- dönen kıvılcımlar
               if (hazir and gir >= 1) then
                    for k = 0, 2 do
                         local a = now * 1.6 + k * (math.pi * 2 / 3) + d.kademe
                         local rr = sz * 0.72
                         K.Sparkle(p.x + math.cos(a) * rr, p.y + math.sin(a) * rr, S(3), ColorAlpha(C.starOn, 210))
                    end
               end

               -- seçim köşeleri
               if (sec) then
                    local m, l = S(5), S(9)
                    local cc = C.ivoryHi
                    K.Box(x - m, y - m, l, 2, cc) K.Box(x - m, y - m, 2, l, cc)
                    K.Box(x + sz + m - l, y - m, l, 2, cc) K.Box(x + sz + m - 2, y - m, 2, l, cc)
                    K.Box(x - m, y + sz + m - 2, l, 2, cc) K.Box(x - m, y + sz + m - l, 2, l, cc)
                    K.Box(x + sz + m - l, y + sz + m - 2, l, 2, cc) K.Box(x + sz + m - 2, y + sz + m - l, 2, l, cc)
               end

               -- rozetler
               if (acik) then
                    local bx, by = x + sz - S(6), y + sz - S(6)
                    K.Box(bx - S(7), by - S(7), S(14), S(14), Color(16, 26, 18, al))
                    K.Outline(bx - S(7), by - S(7), S(14), S(14), ColorAlpha(renk, al))
                    K.Check(bx - S(4), by - S(4), S(8), ColorAlpha(C.ready, al))
               elseif (durum == "kapali" or durum == "yok") then
                    K.Cross(p.x, p.y, S(6), Color(184, 104, 90, 200 * gir))
               elseif (gir >= 1) then
                    local maliyet = durum == "yeniden" and 0 or BA.Maliyet(d.buyu)
                    local t = tostring(maliyet)
                    surface.SetFont("sba.rozet")
                    local tw = surface.GetTextSize(t)
                    local bw = tw + S(10)
                    local bx, by = p.x - bw / 2, y + sz - S(4)
                    K.Box(bx, by, bw, S(13), hazir and Color(93, 41, 36, 235) or Color(18, 22, 18, 220))
                    K.Outline(bx, by, bw, S(13), hazir and C.gold or C.closeLine)
                    Yaz(t, "sba.rozet", p.x, by + S(6.5), hazir and C.ivoryHi or C.studentSm, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

                    if (kilit) then
                         Kilit(K, x + sz - S(4), y + S(5), S(8), C.close)
                    end
               end
          end

          /*
          *   patlamalar
          */

          for i = #st.halka, 1, -1 do
               local r = st.halka[i]
               r.yas = r.yas + ft
               if (r.yas >= r.omur) then
                    table.remove(st.halka, i)
               elseif (r.yas > 0) then
                    local f = r.yas / r.omur
                    local rad = ns * 0.5 + f * ns * 1.6
                    K.Circle(r.x, r.y, rad, ColorAlpha(r.renk, 255 * (1 - f)), 32)
                    K.Circle(r.x, r.y, rad + 1, ColorAlpha(r.renk, 160 * (1 - f)), 32)
               end
          end

          for i = #st.kivilcim, 1, -1 do
               local k = st.kivilcim[i]
               k.yas = k.yas + ft
               if (k.yas >= k.omur) then
                    table.remove(st.kivilcim, i)
               else
                    k.vx = k.vx * (1 - 2.2 * ft)
                    k.vy = k.vy * (1 - 2.2 * ft) + S(60) * ft
                    k.x = k.x + k.vx * ft
                    k.y = k.y + k.vy * ft
                    local f = 1 - k.yas / k.omur
                    Isik(k.x, k.y, k.boy * (0.5 + f * 0.5), k.renk, 255 * f)
               end
          end

          K.Outline(0, 0, w, h, C.detailLine)
     end

     /*
     *   sağ :: ayrıntı şeridi
     */

     local det = vgui.Create("DPanel", P)
     det:SetPos(S(MX), S(H - DET_H))
     det:SetSize(S(MW), S(DET_H))

     local BTN_W = 178

     local function Gosterilen()
          if (st.hover) then return "dugum", st.hover end
          if (st.hoverKademe) then return "kademe", st.hoverKademe end
          if (st.secili) then return "dugum", st.secili end
          return "agac"
     end

     local DURUM_YAZI = {
          biliniyor = {"ÖĞRENİLDİ", "ready"},
          yeniden = {"ÜCRETSİZ GERİ AL", "starOn"},
          acilabilir = {"AÇILABİLİR", "starOn"},
          puan = {"PUAN YETERSİZ", "warn"},
          kademe = {"KADEME KİLİTLİ", "bad"},
          gerek = {"ÖNCEKİ DAL KAPALI", "warn"},
          kapali = {"KAPALI", "bad"},
          yok = {"SUNUCUDA YOK", "bad"}
     }

     det.Paint = function(s, w, h)
          local agac = Agac()
          local c = Durumlar()
          local tur, id = Gosterilen()

          K.Box(0, 0, w, h, Color(11, 19, 17, 200))
          K.Outline(0, 0, w, h, C.detailLine)

          local textW = w - S(BTN_W) - S(40)

          if (tur == "dugum") then
               local d = BA.Dugum(id)
               local ds = c.dugum[id] or {}
               local spell = HpwRewrite:GetSpell(id)

               local es = S(60)
               local ex, ey = S(16), (h - es) / 2
               if (!K.Tex("icon_slot", ex, ey, es, es)) then K.Box(ex, ey, es, es, Color(11, 19, 15)) end
               local mat = K.SpellIcon(id)
               if (mat) then
                    surface.SetMaterial(mat)
                    surface.SetDrawColor(255, 255, 255, ACIK[ds.durum] and 255 or 200)
                    surface.DrawTexturedRect(ex + S(6), ey + S(6), es - S(12), es - S(12))
               end
               if (ACIK[ds.durum]) then K.Outline(ex, ey, es, es, agac.renk) end

               local tx = ex + es + S(16)
               Yaz(id, "sba.bas", tx, S(10), C.heading)

               local dy = DURUM_YAZI[ds.durum] or {"", "hint"}
               local nw = TW(id, "sba.bas")
               K.Spaced(dy[1], "sans8", tx + nw + S(14), S(19), C[dy[2]] or C.hint, S(2))

               local alt = BA.Kademeler[d.kademe].roma .. " · " .. BA.Kademeler[d.kademe].ad .. "   ·   " .. agac.ad .. " › " .. (agac.dallar[d.dal] or "")
               K.Text(alt, "sans9", tx, S(42), C.eyebrow)

               local aciklama = ds.sebep or ""
               if (ds.durum == "biliniyor" or ds.durum == "acilabilir" or ds.durum == "yeniden") then
                    local desc = spell and spell.Description
                    if (isstring(desc)) then
                         desc = string.Trim(string.gsub(desc, "%s+", " "))
                         if (desc != "") then aciklama = desc end
                    end
               end
               local satirlar = K.Wrap(aciklama, "sans10", textW - tx)
               for i = 1, math.min(2, #satirlar) do
                    K.Text(satirlar[i] .. ((i == 2 and #satirlar > 2) and "…" or ""), "sans10", tx, S(56) + (i - 1) * S(15), C.desc)
               end
          elseif (tur == "kademe") then
               local kd = c.kademe[id] or {}
               Yaz(BA.Kademeler[id].roma, "sba.puan", S(26), h / 2, kd.ok and C.gold or C.studentSm, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
               local tx = S(96)
               Yaz(BA.Kademeler[id].ad, "sba.bas", tx, S(12), C.heading)
               K.Spaced(kd.ok and "AÇIK" or "KİLİTLİ", "sans8", tx, S(42), kd.ok and C.ready or C.bad, S(2))
               K.Text("Bu kademede büyü başına " .. (BA.Ayar.kademeMaliyet[id] or 0) .. " Büyü Puanı (özel ayarlananlar hariç).", "sans10", tx + S(70), S(46), C.hint, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
               local satirlar = K.Wrap(kd.sebep or "", "sans10", textW - tx)
               for i = 1, math.min(2, #satirlar) do K.Text(satirlar[i], "sans10", tx, S(58) + (i - 1) * S(15), C.desc) end
          else
               local il = c.ilerleme[agac.id] or {0, 0}
               Yaz(agac.ad, "sba.bas", S(16), S(10), C.heading)
               K.Spaced(il[1] .. " / " .. il[2] .. " BÜYÜ", "sans8", S(16) + TW(agac.ad, "sba.bas") + S(14), S(19), C.eyebrow, S(2))
               local satirlar = K.Wrap(agac.aciklama or "", "sans10", textW - S(16))
               for i = 1, math.min(2, #satirlar) do K.Text(satirlar[i], "sans10", S(16), S(42) + (i - 1) * S(15), C.desc) end
               K.Text("Bir büyüye tıkla; çift tıklama ya da sağdaki düğme ile aç. Soldaki kademe adının üstüne gelince kilidin koşulunu görürsün.", "sans9", S(16), h - S(14), C.hint, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
          end

          K.Box(w - S(BTN_W) - S(26), S(12), 1, h - S(24), C.navLine)

          -- düğmenin üstü: maliyet ve eldeki puan
          local bx = w - S(BTN_W) / 2 - S(14)
          if (tur == "dugum" and !ACIK[(c.dugum[id] or {}).durum]) then
               local m = (c.dugum[id] or {}).durum == "yeniden" and 0 or BA.Maliyet(id)
               K.Text("MALİYET " .. m .. "   ·   SENDE " .. c.puan, "sans9", bx, S(24), m <= c.puan and C.ready or C.warn, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
          elseif (tur == "dugum") then
               local od = BA.Odenen(Char(), id)
               K.Text(od and ("Ağaçtan " .. od .. " puanla açtın") or "Ders / parşömen ile öğrenildi", "sans9", bx, S(24), C.ready, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
          else
               K.Text("Büyü Puanı: " .. c.puan, "sans9", bx, S(24), C.hint, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
          end
     end

     local btn = vgui.Create("DButton", det)
     btn:SetPos(S(MW) - S(BTN_W) - S(14), S(DET_H) - S(14) - S(36))
     btn:SetSize(S(BTN_W), S(36))
     btn:SetText("")

     local function BtnDurum()
          if (!st.secili) then return nil end
          if (st.hover and st.hover != st.secili) then return nil end
          local c = Durumlar()
          local ds = c.dugum[st.secili]
          return ds and ds.durum
     end

     btn.Paint = function(s, w, h)
          local durum = BtnDurum()
          if (!durum) then return end

          local en = durum == "acilabilir" or durum == "yeniden"
          local hov = s:IsHovered() and en
          local label

          if (durum == "biliniyor") then label = "Öğrenildi"
          elseif (durum == "yeniden") then label = st.onay and "Onayla · geri al" or "Ücretsiz geri al"
          elseif (durum == "acilabilir") then label = st.onay and ("Onayla · −" .. BA.Maliyet(st.secili)) or ("Öğren · " .. BA.Maliyet(st.secili) .. " puan")
          elseif (durum == "puan") then label = BA.Maliyet(st.secili) .. " puan gerekli"
          else label = "Kilitli" end

          if (en) then
               if (!K.Slice3(hov and "button_hover" or "button_primary", 0, 0, w, h, 24)) then K.Box(0, 0, w, h, C.primFall) end
               K.Outline(0, 0, w, h, st.onay and C.ivoryHi or C.primLine)
               if (st.onay) then
                    local f = 0.5 + math.sin(RealTime() * 8) * 0.5
                    K.Box(0, 0, w, h, Color(255, 230, 190, 10 + f * 20))
               end
          else
               K.Box(0, 0, w, h, Color(18, 24, 19, 200))
               K.Outline(0, 0, w, h, C.closeLine)
          end

          local up = K.Upper(label)
          local c = en and C.primText or C.studentSm
          local _, th = K.TextW(up, "primary")
          K.Spaced(up, "primary", w / 2, (h - th) / 2, c, S(1.5), TEXT_ALIGN_CENTER)
     end

     btn.Think = function(s)
          local durum = BtnDurum()
          s:SetVisible(durum != nil)
          s:SetCursor((durum == "acilabilir" or durum == "yeniden") and "hand" or "arrow")
          if (st.onay and (st.onay.buyu != st.secili or RealTime() > st.onay.t)) then st.onay = nil end
     end

     st.AcDene = function(dogrudan)
          local durum = BtnDurum() or (st.secili and Durumlar().dugum[st.secili] and Durumlar().dugum[st.secili].durum)
          if (durum != "acilabilir" and durum != "yeniden") then
               surface.PlaySound("buttons/button10.wav")
               return
          end

          if (!dogrudan and !st.onay) then
               st.onay = {buyu = st.secili, t = RealTime() + 3}
               N.SndClick()
               return
          end

          st.onay = nil
          st.bekleyen = st.secili
          N.SndClick()
          BA.AcIstegi(st.secili)
     end

     btn.DoClick = function()
          st.AcDene(false)
     end

     /*
     *   sunucu yanıtı :: açık sayfa kendi patlamasını çizer
     */

     -- kimlik tuval: sayfa değişince content:Clear() onu siler, kanca da kendiliğinden düşer
     hook.Add("SardonBuyuAgaciSonuc", tuval, function(_, ok, metin, buyu)
          if (!tuval:IsVisible() or !IsValid(ctx.menu) or !ctx.menu:IsVisible()) then return end

          Gecersiz()
          if (ok) then
               local d, agac = BA.Dugum(buyu)
               if (agac and agac.id != st.agac) then AgacSec(agac.id) end
               timer.Simple(0.05, function()
                    if (IsValid(tuval)) then Patlat(buyu, agac and agac.renk or C.gold) end
               end)
               surface.PlaySound("ui/achievement_earned.wav")
               if (ctx.menu.Flash) then ctx.menu:Flash(metin) end
               -- karakter verisi bir tık sonra gelir
               timer.Simple(0.3, Gecersiz)
               timer.Simple(1, Gecersiz)
          else
               surface.PlaySound("buttons/button10.wav")
               if (ctx.menu.Flash) then ctx.menu:Flash(metin, "bad") end
          end

          return true
     end)

     hook.Add("SardonBuyuAgaciAyar", tuval, function() Gecersiz() end)

     ctx.SetHead({
          note = function()
               local c = Durumlar()
               return c.puan .. " BÜYÜ PUANI"
          end
     })

     return function()
          Gecersiz()
     end
end

/*
*   kayıt :: asa menüsü yüklendiğinde (yükleme sırası belli değil, birkaç kez denenir)
*/

local function Kaydol()
     local N = HpwRewrite and HpwRewrite.Nocturne
     if (!N or !N.Kitap or !N.Kitap.S) then return false end

     N.Pages = N.Pages or {}
     N.Pages.buyuagaci = {
          id = "buyuagaci",
          label = "Büyü Ağacı",
          title = "Büyü Ağacı  ·  derslerden kazandığın Büyü Puanı ile yeni büyüler aç",
          build = Build
     }

     -- açık pencere eski sekme listesiyle kurulduysa yeniden kurulsun
     local win = HpwRewrite.VGUI and HpwRewrite.VGUI.Window
     if (IsValid(win) and win.Theme == "kitap" and !win:IsVisible()) then
          win:Remove()
          HpwRewrite.VGUI.Window = nil
     end

     return true
end

if (!Kaydol()) then
     timer.Create("SardonBuyuAgaci.Sayfa", 2, 30, function()
          if (Kaydol()) then timer.Remove("SardonBuyuAgaci.Sayfa") end
     end)
end
