-- "addons\\sardonbakanlik\\lua\\sardon_bakanlik\\cl_0tema.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Bakanlık :: istemci tema + arayüz araç takımı (B.UI).
--
-- GÖRSEL DİL: Karakter Gelişimi (SHINE Celestial) ve asa menüsüyle aynı: kömür yeşili zemin,
-- eskitilmiş altın ince çizgiler, fildişi başlıklar, adaçayı gövde metni, harf aralıklı büyük
-- harf etiketler, baklava süsler. Renkler [sardon] gelisim cl_2ekran.lua R tablosundan.
--
-- ÇİZİM MODELİ: tek tasarım alanı 1600x900, ekrana ölçeklenip ortalanır. Araç takımı "anlık
-- kip"tir: sayfalar her karede U.Dugme / U.Girdi / U.Kaydir çağırır; tıklama bir sonraki
-- çizimde, üstünde durduğu bileşen tarafından tüketilir. Yazı kutuları gerçek DTextEntry
-- çocuklarıdır (kimlikle bir kez yaratılır, her kare yerine oturtulur).
--
-- Bu dosya düz Lua'dır (!=, continue yok): ~/araclar/vgui-onizleme düzeneğinde de çalışır.

local B = SardonBakanlik

B.UI = B.UI or {}
local U = B.UI

local function Renk(hex, a)
     hex = string.gsub(hex, "#", "")
     return Color(tonumber(string.sub(hex, 1, 2), 16), tonumber(string.sub(hex, 3, 4), 16), tonumber(string.sub(hex, 5, 6), 16), a and math.Round(a * 255) or 255)
end

U.R = {
     zemin = Renk("#0b1311"), zeminKoyu = Renk("#070b09"), panel = Renk("#0f1a15"), panelAcik = Renk("#15231c"),
     fildisi = Renk("#e8dbb6"), fildisiAcik = Renk("#f2e0b3"), altin = Renk("#bea268"), altinAcik = Renk("#dfc180"),
     pirinc = Renk("#9c8050"), ust = Renk("#bba679"), govde = Renk("#bec2b0"), ada = Renk("#aeb599"), soluk = Renk("#8a977d"),
     cizgi = Renk("#7d6845"), butonYazi = Renk("#e8d4a4"), kapali = Renk("#657476"),
     kizil = Renk("#d66054"), kizilKoyu = Renk("#632b28"), yesil = Renk("#8fc79a"), mavi = Renk("#9cc3d6"), mor = Renk("#b9a6d9"),
     siyah = Color(0, 0, 0), beyaz = Color(255, 255, 255),
}
local R = U.R

U.TW, U.TH = 1600, 900
U.S, U.OX, U.OY = 1, 0, 0

local function X(x) return U.OX + x * U.S end
local function Y(y) return U.OY + y * U.S end
U.X, U.Y = X, Y

function U.Olcekle(w, h)
     U.S = math.min(w / U.TW, h / U.TH)
     U.OX = math.floor((w - U.TW * U.S) / 2)
     U.OY = math.floor((h - U.TH * U.S) / 2)
end

function U.Sakin() return cookie.GetNumber("sardon_gelisim_sakin", 0) == 1 end
function U.Zaman() return U.Sakin() and 0 or RealTime() end
function U.Kolay(t) t = math.Clamp(t, 0, 1) return 1 - (1 - t) ^ 3 end

----------------------------------------------------------------------------------------
-- Yazı
----------------------------------------------------------------------------------------
local fontlar = {}
-- 700 = düz gövde metni: küçük boyda Montserrat karışık görünüyor (kullanıcı geri bildirimi, gelisim)
local AILE = {[400] = "Montserrat Medium", [500] = "Montserrat Medium", [600] = "Montserrat SemiBold", [700] = "Arial"}

function U.Font(boy, kalin)
     kalin = kalin or 400
     local px = math.max(11, math.Round(boy * U.S))
     local ad = "SardonBakanlik_" .. px .. "_" .. kalin
     if not fontlar[ad] then
          surface.CreateFont(ad, {font = AILE[kalin] or AILE[400], size = px, weight = kalin, antialias = true, extended = true})
          fontlar[ad] = true
     end
     return ad
end

local sarCache, kisaCache, olcCache = {}, {}, {}

B.Kanca("OnScreenSizeChanged", "SardonBakanlik.Font", function() fontlar, sarCache, kisaCache, olcCache = {}, {}, {}, {} end)

-- Genişlik (tasarım px)
function U.Olc(metin, boy, kalin, aralik)
     metin = tostring(metin)
     local anahtar = metin .. "\0" .. boy .. (kalin or 400) .. (aralik or 0) .. U.S
     local c = olcCache[anahtar]
     if c then return c end

     surface.SetFont(U.Font(boy, kalin))
     local w = surface.GetTextSize(metin)
     if aralik and aralik > 0 then w = w + math.Round(aralik * U.S) * math.max(0, utf8.len(metin) - 1) end
     c = w / U.S
     olcCache[anahtar] = c
     return c
end

-- hiza: 0 sol, 1 orta, 2 sağ; y = satırın orta çizgisi. Dönüş: genişlik (tasarım px)
function U.Yazi(metin, boy, kalin, x, y, renk, hiza, aralik, alfa)
     metin = tostring(metin)
     local f = U.Font(boy, kalin)
     surface.SetFont(f)
     surface.SetTextColor(renk.r, renk.g, renk.b, (alfa or 1) * renk.a)
     local _, th = surface.GetTextSize("A")
     local py = math.Round(Y(y) - th / 2)

     if not aralik or aralik <= 0 then
          local w = surface.GetTextSize(metin)
          surface.SetTextPos(math.Round(X(x) - (hiza == 1 and w / 2 or (hiza == 2 and w or 0))), py)
          surface.DrawText(metin)
          return w / U.S
     end

     local w = U.Olc(metin, boy, kalin, aralik)
     surface.SetFont(f)
     local px = X(x) - (hiza == 1 and w * U.S / 2 or (hiza == 2 and w * U.S or 0))
     local ara = math.Round(aralik * U.S)
     for _, kod in utf8.codes(metin) do
          local c = utf8.char(kod)
          surface.SetTextPos(math.Round(px), py)
          surface.DrawText(c)
          px = px + surface.GetTextSize(c) + ara
     end
     return w
end

-- Küçük, harf aralıklı büyük harf etiket
function U.Etiket(metin, x, y, renk, hiza, boy)
     return U.Yazi(B.Buyuk(metin), boy or 11, 600, x, y, renk or R.ust, hiza or 0, 2.2)
end

-- Kelime kaydırma; "\n" satır başıdır. Dönüş: satır listesi (önbellekli)
function U.Sar(metin, boy, kalin, genislik)
     metin = tostring(metin)
     local anahtar = metin .. "\0" .. boy .. (kalin or 400) .. genislik .. U.S
     local c = sarCache[anahtar]
     if c then return c end

     surface.SetFont(U.Font(boy, kalin))
     local satirlar = {}
     local sinir = genislik * U.S

     for paragraf in string.gmatch(metin .. "\n", "(.-)\n") do
          local cur = ""
          for kelime in string.gmatch(paragraf, "%S+") do
               local aday = cur == "" and kelime or (cur .. " " .. kelime)
               if cur ~= "" and surface.GetTextSize(aday) > sinir then
                    satirlar[#satirlar + 1] = cur
                    cur = kelime
               else
                    cur = aday
               end
          end
          satirlar[#satirlar + 1] = cur
     end
     while #satirlar > 1 and satirlar[#satirlar] == "" do satirlar[#satirlar] = nil end

     sarCache[anahtar] = satirlar
     return satirlar
end

-- Paragraf çizer. Dönüş: kullanılan yükseklik (tasarım px)
function U.Paragraf(metin, boy, kalin, x, y, genislik, renk, satirH, enCok, alfa)
     local satirlar = U.Sar(metin, boy, kalin, genislik)
     satirH = satirH or (boy * 1.45)
     local n = math.min(#satirlar, enCok or #satirlar)
     for i = 1, n do
          local s = satirlar[i]
          if i == n and n < #satirlar then s = s .. " …" end
          U.Yazi(s, boy, kalin, x, y + (i - 0.5) * satirH, renk, 0, nil, alfa)
     end
     return n * satirH
end

function U.ParagrafH(metin, boy, kalin, genislik, satirH, enCok)
     local n = #U.Sar(metin, boy, kalin, genislik)
     return math.min(n, enCok or n) * (satirH or (boy * 1.45))
end

-- Genişliğe sığmayan metni "…" ile keser (önbellekli)
function U.Kisalt(metin, boy, kalin, genislik)
     metin = tostring(metin)
     local anahtar = metin .. "\0" .. boy .. (kalin or 400) .. genislik .. U.S
     local c = kisaCache[anahtar]
     if c then return c end

     c = metin
     if U.Olc(metin, boy, kalin) > genislik then
          local harfler = {}
          for _, kod in utf8.codes(metin) do harfler[#harfler + 1] = utf8.char(kod) end
          local n = #harfler
          while n > 1 do
               n = n - 1
               c = table.concat(harfler, "", 1, n) .. "…"
               if U.Olc(c, boy, kalin) <= genislik then break end
          end
     end
     kisaCache[anahtar] = c
     return c
end

----------------------------------------------------------------------------------------
-- Çizim temelleri
----------------------------------------------------------------------------------------
local matParilti = Material("sprites/glow04_noz", "smooth")
local gradL, gradR = Material("vgui/gradient-l"), Material("vgui/gradient-r")
local gradU, gradD = Material("vgui/gradient-u"), Material("vgui/gradient-d")

function U.Ton(c, a) surface.SetDrawColor(c.r, c.g, c.b, (a or 1) * c.a) end

function U.Kutu(x, y, w, h, c, a)
     surface.SetDrawColor(c.r, c.g, c.b, (a or 1) * c.a)
     surface.DrawRect(math.Round(X(x)), math.Round(Y(y)), math.max(1, math.Round(w * U.S)), math.max(1, math.Round(h * U.S)))
end

function U.Cerceve(x, y, w, h, c, a)
     surface.SetDrawColor(c.r, c.g, c.b, (a or 1) * c.a)
     surface.DrawOutlinedRect(math.Round(X(x)), math.Round(Y(y)), math.max(1, math.Round(w * U.S)), math.max(1, math.Round(h * U.S)), 1)
end

function U.Cizgi(x1, y1, x2, y2, c, a)
     if c then surface.SetDrawColor(c.r, c.g, c.b, (a or 1) * c.a) end
     surface.DrawLine(math.Round(X(x1)), math.Round(Y(y1)), math.Round(X(x2)), math.Round(Y(y2)))
end

-- yon: "l" soldan sağa söner, "r" sağdan sola, "u" yukarıdan aşağı, "d" aşağıdan yukarı
function U.Gecis(x, y, w, h, c, a, yon)
     surface.SetDrawColor(c.r, c.g, c.b, (a or 1) * c.a)
     surface.SetMaterial(yon == "r" and gradR or (yon == "u" and gradU or (yon == "d" and gradD or gradL)))
     surface.DrawTexturedRect(math.Round(X(x)), math.Round(Y(y)), math.max(1, math.Round(w * U.S)), math.max(1, math.Round(h * U.S)))
     draw.NoTexture()
end

-- Ortası parlak, iki ucu sönen yatay çizgi (başlık altı)
function U.SusCizgi(x, y, w, c, a)
     U.Gecis(x + w / 2, y, w / 2, 1, c, a, "l")
     U.Gecis(x, y, w / 2, 1, c, a, "r")
end

local baklavaPoly = {{}, {}, {}, {}}
function U.Baklava(cx, cy, h, c, a)
     if c then surface.SetDrawColor(c.r, c.g, c.b, (a or 1) * c.a) end
     local p = baklavaPoly
     p[1].x, p[1].y = X(cx), Y(cy - h)
     p[2].x, p[2].y = X(cx + h), Y(cy)
     p[3].x, p[3].y = X(cx), Y(cy + h)
     p[4].x, p[4].y = X(cx - h), Y(cy)
     draw.NoTexture()
     surface.DrawPoly(p)
end

function U.BaklavaCizgi(cx, cy, h, c, a)
     if c then surface.SetDrawColor(c.r, c.g, c.b, (a or 1) * c.a) end
     U.Cizgi(cx, cy - h, cx + h, cy) U.Cizgi(cx + h, cy, cx, cy + h)
     U.Cizgi(cx, cy + h, cx - h, cy) U.Cizgi(cx - h, cy, cx, cy - h)
end

local diskPoly = {}
function U.Disk(cx, cy, r, c, a)
     if c then surface.SetDrawColor(c.r, c.g, c.b, (a or 1) * c.a) end
     local n = math.Clamp(math.ceil(r * U.S * 0.8), 8, 64)
     for i = 1, n do
          local ac = (i - 1) / n * 2 * math.pi
          local p = diskPoly[i] or {}
          diskPoly[i] = p
          p.x, p.y = X(cx + math.cos(ac) * r), Y(cy + math.sin(ac) * r)
     end
     for i = n + 1, #diskPoly do diskPoly[i] = nil end
     draw.NoTexture()
     surface.DrawPoly(diskPoly)
end

function U.Halka(cx, cy, r, c, a, a0, a1)
     if c then surface.SetDrawColor(c.r, c.g, c.b, (a or 1) * c.a) end
     a0, a1 = a0 or 0, a1 or (2 * math.pi)
     local n = math.max(6, math.ceil(math.Clamp(r * U.S * 0.6, 12, 96) * math.abs(a1 - a0) / (2 * math.pi)))
     local px, py = X(cx + math.cos(a0) * r), Y(cy + math.sin(a0) * r)
     for i = 1, n do
          local ac = a0 + (a1 - a0) * i / n
          local nx, ny = X(cx + math.cos(ac) * r), Y(cy + math.sin(ac) * r)
          surface.DrawLine(px, py, nx, ny)
          px, py = nx, ny
     end
end

function U.Parilti(cx, cy, boy, c, a)
     surface.SetMaterial(matParilti)
     surface.SetDrawColor(c.r, c.g, c.b, a)
     surface.DrawTexturedRect(X(cx - boy / 2), Y(cy - boy / 2), boy * U.S, boy * U.S)
     draw.NoTexture()
end

-- Doku: kendi gömülü dokularımız (cl_1doku.lua B.Doku) ya da verilen material
function U.Resim(mat, x, y, w, h, c, a)
     if not mat then return false end
     surface.SetMaterial(mat)
     c = c or R.beyaz
     surface.SetDrawColor(c.r, c.g, c.b, (a or 1) * 255)
     surface.DrawTexturedRect(math.Round(X(x)), math.Round(Y(y)), math.Round(w * U.S), math.Round(h * U.S))
     draw.NoTexture()
     return true
end

-- Kart: koyu panel + ince altın çerçeve + köşe baklavaları
function U.Kart(x, y, w, h, vurgu, alfa)
     alfa = alfa or 1
     U.Kutu(x, y, w, h, R.panel, 0.86 * alfa)
     U.Gecis(x, y, w, math.min(h, 46), R.panelAcik, 0.55 * alfa, "u")
     U.Cerceve(x, y, w, h, vurgu and R.altin or R.cizgi, (vurgu and 0.75 or 0.5) * alfa)
     local c = vurgu and R.altinAcik or R.pirinc
     U.Baklava(x, y, 3, c, 0.9 * alfa) U.Baklava(x + w, y, 3, c, 0.9 * alfa)
     U.Baklava(x, y + h, 3, c, 0.9 * alfa) U.Baklava(x + w, y + h, 3, c, 0.9 * alfa)
end

-- Bölüm başlığı: ◆ ETİKET ───────
function U.Bolum(metin, x, y, w, sag)
     U.Baklava(x + 4, y, 4, R.altin, 0.9)
     local tw = U.Etiket(metin, x + 16, y, R.ust)
     local bas = x + 16 + tw + 12
     local son = x + w
     if sag then
          local sw = U.Yazi(sag, 12, 700, x + w, y, R.soluk, 2)
          son = x + w - sw - 10
     end
     if son > bas then U.Gecis(bas, y, son - bas, 1, R.cizgi, 0.7, "l") end
end

-- Küçük hap rozet. Dönüş: genişlik
function U.Rozet(metin, x, y, c, dolu, hiza)
     metin = B.Buyuk(metin)
     local w = U.Olc(metin, 10, 600, 1.4) + 16
     if hiza == 2 then x = x - w end
     if dolu then U.Kutu(x, y - 9, w, 18, c, 0.22) end
     U.Cerceve(x, y - 9, w, 18, c, 0.8)
     U.Yazi(metin, 10, 600, x + w / 2, y, c, 1, 1.4)
     return w
end

----------------------------------------------------------------------------------------
-- Girdi (fare, tekerlek, klavye)
----------------------------------------------------------------------------------------
U.fareX, U.fareY = 0, 0
U.tik = nil         -- {x, y, kod} ekran px; tüketilince nil
U.teker = 0
U.engel = false     -- kip penceresi açıkken alttaki sayfa girdi almaz
U.klip = nil        -- {x, y, w, h} tasarım px; kaydırma alanı içindeyken
U.imlec = false
U.ipucu = nil

function U.Icinde(x, y, w, h)
     if U.engel then return false end
     local mx, my = U.fareX, U.fareY
     if mx < X(x) or mx >= X(x + w) or my < Y(y) or my >= Y(y + h) then return false end
     local k = U.klip
     if k and (mx < X(k.x) or mx >= X(k.x + k.w) or my < Y(k.y) or my >= Y(k.y + k.h)) then return false end
     return true
end

-- Sol tık bu karede bu alana mı geldi? (tüketir)
function U.Tik(x, y, w, h, kod)
     local t = U.tik
     if not t or U.engel or t.kod ~= (kod or MOUSE_LEFT) then return false end
     if t.x < X(x) or t.x >= X(x + w) or t.y < Y(y) or t.y >= Y(y + h) then return false end
     local k = U.klip
     if k and (t.x < X(k.x) or t.x >= X(k.x + k.w) or t.y < Y(k.y) or t.y >= Y(k.y + k.h)) then return false end
     U.tik = nil
     return true
end

function U.Ses(ad)
     local yol = ({
          tik = "garrysmod/ui_click.wav", uzeri = "garrysmod/ui_hover.wav", geri = "garrysmod/ui_return.wav",
          sayfa = "physics/cardboard/cardboard_box_impact_soft2.wav", muhur = "physics/wood/wood_box_impact_hard3.wav",
          hata = "buttons/button10.wav", tamam = "garrysmod/content_downloaded.wav", kagit = "physics/cardboard/cardboard_box_impact_soft5.wav",
     })[ad]
     if yol then surface.PlaySound(yol) end
end

-- Düğme. stil: "ana" | "ikincil" | "tehlike" | "duz". Dönüş: tıklandı mı
function U.Dugme(x, y, w, h, metin, stil, kapali, ipucu)
     stil = stil or "ikincil"
     local ustunde = not kapali and U.Icinde(x, y, w, h)
     local c = stil == "tehlike" and R.kizil or R.altin
     if kapali then c = R.kapali end

     if stil == "ana" then
          U.Kutu(x, y, w, h, c, kapali and 0.08 or (ustunde and 0.34 or 0.2))
     elseif ustunde then
          U.Kutu(x, y, w, h, c, 0.14)
     end
     if stil ~= "duz" or ustunde then U.Cerceve(x, y, w, h, c, kapali and 0.4 or (ustunde and 1 or 0.7)) end
     if stil == "ana" and not kapali then
          U.Baklava(x, y + h / 2, 3, R.altinAcik, 1) U.Baklava(x + w, y + h / 2, 3, R.altinAcik, 1)
     end

     local yc = kapali and R.kapali or (stil == "tehlike" and R.kizil or (ustunde and R.fildisiAcik or R.butonYazi))
     local boy = h >= 34 and 12 or 11
     U.Yazi(B.Buyuk(U.Kisalt(metin, boy, 600, (w - 14) / 1.18)), boy, 600, x + w / 2, y + h / 2, yc, 1, 1.6)

     if ustunde then
          U.imlec = true
          if ipucu then U.ipucu = ipucu end
          if U.Tik(x, y, w, h) then
               U.Ses("tik")
               return true
          end
     elseif kapali and ipucu and U.Icinde(x, y, w, h) then
          U.ipucu = ipucu
     end
     return false
end

-- Sekme şeridi. liste: {{id, ad, rozet}}. Dönüş: tıklanan sekmenin id'si (yoksa nil), şerit genişliği
function U.Sekmeler(x, y, liste, secili)
     local cx, tiklanan = x, nil
     for _, s in ipairs(liste) do
          local ad = B.Buyuk(s.ad)
          local w = U.Olc(ad, 12, 600, 1.8) + 28
          if s.rozet and s.rozet > 0 then w = w + 24 end
          local sec = s.id == secili
          local ustunde = U.Icinde(cx, y, w, 34)

          U.Yazi(ad, 12, 600, cx + 14, y + 16, sec and R.fildisiAcik or (ustunde and R.butonYazi or R.soluk), 0, 1.8)
          if s.rozet and s.rozet > 0 then
               U.Disk(cx + w - 20, y + 16, 9, R.altin, 0.9)
               U.Yazi(s.rozet, 10, 700, cx + w - 20, y + 16, R.zeminKoyu, 1)
          end
          if sec then
               U.Kutu(cx + 8, y + 32, w - 16, 2, R.altin, 1)
               U.Baklava(cx + w / 2, y + 33, 4, R.altinAcik, 1)
          end
          if ustunde then
               U.imlec = true
               if not sec and U.Tik(cx, y, w, 34) then
                    U.Ses("uzeri")
                    tiklanan = s.id
               end
          end
          cx = cx + w
     end
     U.Gecis(x, y + 34, 900, 1, R.cizgi, 0.6, "l")
     return tiklanan, cx - x
end

-- Onay kutusu. Dönüş: tıklandı mı
function U.Kutucuk(x, y, metin, isaretli, kapali)
     local w = 22 + U.Olc(metin, 13, 700) + 6
     local ustunde = not kapali and U.Icinde(x, y - 11, w, 22)
     U.BaklavaCizgi(x + 8, y, 7, kapali and R.kapali or R.altin, ustunde and 1 or 0.8)
     if isaretli then U.Baklava(x + 8, y, 4, R.altinAcik, 1) end
     U.Yazi(metin, 13, 700, x + 24, y, kapali and R.kapali or (ustunde and R.fildisi or R.govde))
     if ustunde then
          U.imlec = true
          if U.Tik(x, y - 11, w, 22) then
               U.Ses("tik")
               return true
          end
     end
     return false
end

----------------------------------------------------------------------------------------
-- Kaydırma alanı
----------------------------------------------------------------------------------------
local kaydirma = {} -- [id] = {y, hedef}

-- Alanı açar; içerik U.KaydirY() kadar yukarı kaydırılarak çizilir. Dönüş: kaydırma (tasarım px)
function U.Kaydir(id, x, y, w, h, icerikH)
     local k = kaydirma[id]
     if not k then
          k = {y = 0, hedef = 0}
          kaydirma[id] = k
     end

     local ust = math.max(0, icerikH - h)
     if U.teker ~= 0 and U.Icinde(x, y, w, h) then
          k.hedef = k.hedef - U.teker * 64
          U.teker = 0
     end
     k.hedef = math.Clamp(k.hedef, 0, ust)
     k.y = Lerp(math.min(1, RealFrameTime() * 16), k.y, k.hedef)
     if math.abs(k.y - k.hedef) < 0.5 then k.y = k.hedef end

     -- kaydırma çubuğu
     if ust > 0 then
          local cubukH = math.max(24, h * h / icerikH)
          local cy = y + (h - cubukH) * (k.y / ust)
          U.Kutu(x + w - 3, y, 1, h, R.cizgi, 0.35)
          U.Kutu(x + w - 4, cy, 3, cubukH, R.altin, 0.75)
     end

     U.klip = {x = x, y = y, w = w, h = h}
     render.SetScissorRect(math.floor(X(x)), math.floor(Y(y)), math.ceil(X(x + w)), math.ceil(Y(y + h)), true)
     return k.y
end

function U.KaydirBitir()
     render.SetScissorRect(0, 0, 0, 0, false)
     U.klip = nil
end

function U.KaydirSifirla(id)
     if kaydirma[id] then kaydirma[id].y, kaydirma[id].hedef = 0, 0 end
end

-- Satır görünür mü? (kaydırma alanı içinde gereksiz çizimi atlamak için)
function U.Gorunur(y, h)
     local k = U.klip
     if not k then return true end
     return y + h >= k.y and y <= k.y + k.h
end

-- Tıklanabilir liste satırı zemini. Dönüş: tıklandı, üstünde
function U.Satir(x, y, w, h, secili)
     local ustunde = U.Icinde(x, y, w, h)
     if secili then
          U.Kutu(x, y, w, h, R.altin, 0.13)
          U.Kutu(x, y, 2, h, R.altinAcik, 1)
     elseif ustunde then
          U.Kutu(x, y, w, h, R.altin, 0.07)
     end
     U.Kutu(x, y + h - 1, w, 1, R.cizgi, 0.28)
     if ustunde then
          U.imlec = true
          if U.Tik(x, y, w, h) then
               U.Ses("uzeri")
               return true, true
          end
     end
     return false, ustunde
end

----------------------------------------------------------------------------------------
-- Yazı kutuları (DTextEntry çocukları) ve portre (DModelPanel)
----------------------------------------------------------------------------------------
U.panel = nil
local girdiler = {}  -- [id] = panel
local modeller = {}  -- [id] = panel
local kullanilan = {}
U.enter = {}

local function GirdiYarat(id, secenek)
     local p = vgui.Create("DTextEntry", U.panel)
     p:SetPaintBackground(false)
     p:SetDrawLanguageID(false)
     p:SetUpdateOnType(true)
     p:SetMultiline(secenek.cokSatir and true or false)
     if secenek.sayi then p:SetNumeric(true) end
     p.sbMaks = secenek.maks
     p.AllowInput = function(s, harf)
          return s.sbMaks and #s:GetValue() >= s.sbMaks
     end
     p.OnEnter = function() U.enter[id] = true end
     p.Paint = function(s, w, h)
          s:DrawTextEntryText(R.fildisi, R.altin, R.altinAcik)
     end
     return p
end

-- Dönüş: kutudaki metin. secenek: {cokSatir, sayi, maks, deger (ilk değer)}
function U.Girdi(id, x, y, w, h, yerTutucu, secenek)
     secenek = secenek or {}
     local p = girdiler[id]
     if not IsValid(p) then
          p = GirdiYarat(id, secenek)
          girdiler[id] = p
          if secenek.deger then p:SetText(tostring(secenek.deger)) end
     end

     local odak = p:HasFocus()
     U.Kutu(x, y, w, h, R.zeminKoyu, 0.7)
     U.Cerceve(x, y, w, h, odak and R.altinAcik or R.cizgi, odak and 0.95 or 0.75)

     local deger = p:GetValue()
     if deger == "" and not odak and yerTutucu then
          U.Yazi(U.Kisalt(yerTutucu, 13, 700, w - 20), 13, 700, x + 10, secenek.cokSatir and (y + 16) or (y + h / 2), R.soluk, 0, nil, 0.8)
     end

     if U.engel then
          -- kip penceresi açık: kutu görünür kalır ama yazılamaz
          p:SetVisible(false)
          if deger ~= "" then U.Yazi(U.Kisalt(deger, 13, 700, w - 20), 13, 700, x + 10, secenek.cokSatir and (y + 16) or (y + h / 2), R.govde) end
     else
          p:SetVisible(true)
          p:SetFontInternal(U.Font(13, 700))
          p:SetPos(math.Round(X(x)) + 6, math.Round(Y(y)) + 2)
          p:SetSize(math.Round(w * U.S) - 12, math.Round(h * U.S) - 4)
          kullanilan[p] = true
     end

     return deger
end

function U.GirdiDeger(id)
     local p = girdiler[id]
     return IsValid(p) and p:GetValue() or ""
end

function U.GirdiAyarla(id, metin)
     local p = girdiler[id]
     if IsValid(p) then p:SetText(tostring(metin or "")) end
end

function U.GirdiOdak(id)
     local p = girdiler[id]
     if IsValid(p) then p:RequestFocus() end
end

-- Enter'a basıldı mı? (bir kez true döner)
function U.GirdiEnter(id)
     if U.enter[id] then
          U.enter[id] = nil
          return true
     end
     return false
end

-- Kimlikleri verilen öneke uyan kutuları yok et (sayfa / kip değişince)
function U.GirdiTemizle(onek)
     for id, p in pairs(girdiler) do
          if not onek or string.sub(id, 1, #onek) == onek then
               if IsValid(p) then p:Remove() end
               girdiler[id] = nil
          end
     end
end

-- Portre: karakter modelinin baş çekimi. ogr: kaydın öğrenci görünümü (sunucu SardonOgrenci.AfisGorunum);
-- öğrenci gövdesi onunla giydirilir, yoksa yalnız taban (bakanın kendi görünümü konmaz)
function U.Model(id, x, y, w, h, model, ogr)
     U.Kutu(x, y, w, h, R.zeminKoyu, 0.75)
     U.Gecis(x, y + h * 0.4, w, h * 0.6, R.altin, 0.1, "d")

     if not model or model == "" or U.engel then
          local m = modeller[id]
          if IsValid(m) then m:SetVisible(false) end
          U.Disk(x + w / 2, y + h * 0.36, w * 0.17, R.cizgi, 0.5)
          U.Disk(x + w / 2, y + h * 0.9, w * 0.34, R.cizgi, 0.5)
          U.Cerceve(x, y, w, h, R.altin, 0.6)
          return
     end

     local m = modeller[id]
     if not IsValid(m) then
          m = vgui.Create("DModelPanel", U.panel)
          m:SetMouseInputEnabled(false)
          m.LayoutEntity = function() end
          m.PostDrawModel = function(_, ent)
               if ent.sogS and SardonOgrenci and SardonOgrenci.ParcaCiz then SardonOgrenci.ParcaCiz(ent) end
          end
          modeller[id] = m
     end
     if m.sbModel ~= model or m.sbOgr ~= ogr then
          m.sbModel, m.sbOgr = model, ogr
          m:SetModel(model)
          local ent = m.Entity
          if IsValid(ent) then
               if SardonOgrenci and SardonOgrenci.KayitGiydir then
                    SardonOgrenci.KayitGiydir(ent, ogr)
               else
                    ent.sogElle = true
               end
               local kemik = ent:LookupBone("ValveBiped.Bip01_Head1")
               local bas = kemik and ent:GetBonePosition(kemik) or Vector(0, 0, 64)
               m:SetLookAt(bas)
               m:SetCamPos(bas + Vector(34, -8, 2))
               m:SetFOV(34)
               ent:SetEyeTarget(bas + Vector(34, -8, 2))
          end
     end
     m:SetVisible(true)
     m:SetPos(math.Round(X(x)) + 1, math.Round(Y(y)) + 1)
     m:SetSize(math.Round(w * U.S) - 2, math.Round(h * U.S) - 2)
     kullanilan[m] = true
     U.Cerceve(x, y, w, h, R.altin, 0.6)
end

----------------------------------------------------------------------------------------
-- Kare başı / sonu
----------------------------------------------------------------------------------------
function U.Basla(panel, w, h)
     U.panel = panel
     U.Olcekle(w, h)
     U.fareX, U.fareY = panel:CursorPos()
     U.imlec = false
     U.ipucu = nil
     U.engel = false
     U.klip = nil
     kullanilan = {}
end

function U.Bitir()
     for _, p in pairs(girdiler) do
          if IsValid(p) and not kullanilan[p] and p:IsVisible() then p:SetVisible(false) end
     end
     for _, m in pairs(modeller) do
          if IsValid(m) and not kullanilan[m] and m:IsVisible() then m:SetVisible(false) end
     end
     U.tik = nil
     U.teker = 0
     if IsValid(U.panel) then U.panel:SetCursor(U.imlec and "hand" or "arrow") end
end

function U.HepsiniYokEt()
     for id, p in pairs(girdiler) do
          if IsValid(p) then p:Remove() end
          girdiler[id] = nil
     end
     for id, m in pairs(modeller) do
          if IsValid(m) then m:Remove() end
          modeller[id] = nil
     end
     kaydirma = {}
     U.enter = {}
end

----------------------------------------------------------------------------------------
-- Hareketli süsler
----------------------------------------------------------------------------------------
local tozlar

-- Yavaşça yükselen altın toz zerreleri (Sakin mod kapatır)
function U.Toz(adet)
     if U.Sakin() then return end
     if not tozlar then
          tozlar = {}
          for i = 1, adet or 26 do
               tozlar[i] = {x = math.Rand(0, U.TW), y = math.Rand(0, U.TH), hiz = math.Rand(5, 16), boy = math.Rand(5, 13), faz = math.Rand(0, 6.28), sal = math.Rand(10, 34)}
          end
     end
     local t = RealTime()
     for _, z in ipairs(tozlar) do
          local y = (z.y - t * z.hiz) % U.TH
          local x = z.x + math.sin(t * 0.4 + z.faz) * z.sal
          local a = 26 + 22 * math.sin(t * 0.9 + z.faz)
          U.Parilti(x, y, z.boy, R.altinAcik, a)
     end
end

-- Nefes alan küçük yıldız
function U.Yildiz(x, y, r, faz)
     local t = U.Zaman()
     local n = 0.55 + 0.45 * math.sin(t * 1.3 + (faz or 0))
     U.Parilti(x, y, r * 7, R.altinAcik, 40 * n)
     U.Baklava(x, y, r * (0.8 + 0.3 * n), R.fildisiAcik, 0.5 + 0.5 * n)
end

-- Mühür basma: U.MuhurBas(x, y) tetikler, U.MuhurCiz() PaintOver'da çizer
local muhurler = {}

function U.MuhurBas(x, y, renk)
     muhurler[#muhurler + 1] = {x = x, y = y, an = RealTime(), renk = renk}
     U.Ses("muhur")
end

function U.MuhurCiz()
     local simdi = RealTime()
     for i = #muhurler, 1, -1 do
          local m = muhurler[i]
          local t = simdi - m.an
          if t > 1.6 then
               table.remove(muhurler, i)
          else
               local vur = U.Kolay(t / 0.16)
               local olcek = 2.4 - 1.4 * vur
               local alfa = t < 1.1 and math.min(1, t / 0.08) or (1 - (t - 1.1) / 0.5)
               local boy = 92 * olcek
               local mat = B.Doku and B.Doku("mum")
               if mat then
                    U.Resim(mat, m.x - boy / 2, m.y - boy / 2, boy, boy, R.beyaz, alfa)
               else
                    U.Disk(m.x, m.y, boy * 0.42, m.renk or R.kizilKoyu, alfa)
                    U.Halka(m.x, m.y, boy * 0.33, R.kizil, alfa)
                    U.Yazi("M", 30 * olcek, 600, m.x, m.y, R.kizil, 1, nil, alfa)
               end
               if t > 0.14 and t < 0.6 then
                    local k = (t - 0.14) / 0.46
                    U.Halka(m.x, m.y, 44 + 60 * k, R.altinAcik, (1 - k) * 0.7)
                    U.Parilti(m.x, m.y, 150 + 120 * k, R.altinAcik, 70 * (1 - k))
               end
          end
     end
end

-- Protean mürekkebi: başkası sayfayı değiştirdiğinde içerik alanından geçen altın çizgi
U.murekkepAn = 0
function U.Murekkep() U.murekkepAn = RealTime() end

function U.MurekkepCiz(x, y, w, h)
     local t = RealTime() - U.murekkepAn
     if t > 0.9 or U.Sakin() then return end
     local k = U.Kolay(t / 0.9)
     local cx = x + w * k
     U.Gecis(cx - 180, y, 180, h, R.altin, 0.1 * (1 - k), "r")
     U.Kutu(cx, y, 1, h, R.altinAcik, 0.8 * (1 - k))
     U.Parilti(cx, y + h * (0.5 + 0.4 * math.sin(t * 9)), 60, R.altinAcik, 160 * (1 - k))
end

----------------------------------------------------------------------------------------
-- Gömülü dokular (cl_0doku_NN.lua; tools/doku_uret.py üretir)
-- Sunucu materials/ dağıtmadığı için veri data/sardon_bakanlik/ altına yazılıp oradan yüklenir.
----------------------------------------------------------------------------------------
local dokuOnbellek = {}

function B.Doku(ad)
     local mat = dokuOnbellek[ad]
     if mat ~= nil then return mat or nil end

     mat = false
     local veri = B.DokuVeri and B.DokuVeri[ad]
     if veri then
          local yol = "sardon_bakanlik/" .. ad .. "_" .. (B.DokuSurum[ad] or "0") .. "." .. (B.DokuUzanti[ad] or "png")
          if not file.Exists(yol, "DATA") then
               file.CreateDir("sardon_bakanlik")
               local ikili = util.Base64Decode(veri)
               if ikili then file.Write(yol, ikili) end
          end
          local m = Material("../data/" .. yol, "smooth mips")
          if not m:IsError() then mat = m end
     end

     dokuOnbellek[ad] = mat
     return mat or nil
end

-- Karakter Gelişimi'nin arka planı ve arması ödünç alınır (yüklü değilse nil)
function U.GelisimDoku(ad)
     if SardonGelisim and SardonGelisim.Doku then return SardonGelisim.Doku(ad) end
end
