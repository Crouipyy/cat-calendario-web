-- "addons\\sardonduyuru\\lua\\sardon_duyuru\\cl_1cizim.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
--[[
     Sardon Duyuru :: ekrandaki bant (istemci).

     Legacy HUD dili: üst ortada, pusulanın ve bölge adının altında, ortası opak iki yana sönen sıcak koyu
     sis; tür renginde harf aralıklı etiket (DUYURU · imza), isteğe bağlı Cinzel başlık, ortadan açılan
     ince çizgi ve Legacy elması, Montserrat gövde, varsa geri sayım. Altta kalan süre, iki uçtan ortaya
     kısalan ince ışık. Giriş: yukarıdan süzülüp belirir, etiketin üstünden bir ışık geçer.
     Sıra: aynı anda tek bant. Yenisi gelince görünen en az 4 sn kaldıktan sonra söner, sıradaki açılır.
     Geri sayımlı duyuru: bant kapanınca pusula altında küçük şerit kalır (tür · başlık · 12:34);
     5 ve 1 dakika kala bant sesle yeniden açılır, süre dolunca şerit "ŞİMDİ" der ve söner.
     PostRenderVGUI'de çizilir: menülerin ve karakter ekranının da üstünde (rol dışı; herkes görmeli).
     İmleç bandın üstündeyse bant saydamlaşır. Bandın ve şeridin durağan kısmı (sis + yazılar) bir kez
     Legacy RT katmanına pişer, ekrana tek dörtgen basılır; Legacy yüklü değilse doğrudan çizilir.
     Boştayken kanca ilk satırda döner.
]]

local D = SardonDuyuru

local math_min, math_max, math_floor, math_ceil, math_Clamp, math_sin, math_pi, math_Round, math_Approach =
     math.min, math.max, math.floor, math.ceil, math.Clamp, math.sin, math.pi, math.Round, math.Approach
local surface_SetDrawColor, surface_SetMaterial, surface_DrawRect = surface.SetDrawColor, surface.SetMaterial, surface.DrawRect
local surface_DrawTexturedRect, surface_DrawPoly = surface.DrawTexturedRect, surface.DrawPoly
local surface_SetFont, surface_GetTextSize = surface.SetFont, surface.GetTextSize
local surface_SetTextColor, surface_SetTextPos, surface_DrawText = surface.SetTextColor, surface.SetTextPos, surface.DrawText
local draw_NoTexture = draw.NoTexture
local RealTime, FrameTime, FrameNumber, ScrW, ScrH, IsValid = RealTime, FrameTime, FrameNumber, ScrW, ScrH, IsValid

-- kalıcı: canlı yenilemede ekrandakiler kaybolmasın
D.Kuyruk = D.Kuyruk or {}         -- bekleyen bantlar
D.Sayaclar = D.Sayaclar or {}     -- [id] = süren geri sayım (şerit)

local YAZI = Color(244, 236, 220)
local FILDISI = Color(250, 240, 214)
local SOLUK = Color(196, 186, 166)
local KOYU = Color(18, 12, 2, 235)

-- Ölçek ekran yüksekliğinden; RT'ye pişirirken ScrH() RT'nin yüksekliğini verdiği için değer RT dışında
-- (Ciz başında, önizlemede) okunup saklanır. Pişen kısım bu yüzden ekrandakiyle birebir aynı ölçekte.
local ekranH = ScrH()
local function EkranOku() ekranH = ScrH() end
local function O(x) return x * ekranH / 1080 end
local function Yum(x) x = math_Clamp(x, 0, 1) return x * x * (3 - 2 * x) end
local function Sonum(x) x = 1 - math_Clamp(x, 0, 1) return 1 - x * x * x end

local function Legacy()
     local H = SardonHUD
     local L = H and H.Legacy
     return L and L.Katman and L.KatmanCiz and L.KatmanBas and L or nil
end

-- PostRenderVGUI'de derinlik testi açık kalıyor: $ignorez'siz dokulu malzeme görünmüyor
-- ([sardon] huds cl_legacy_5bildirim ile aynı çözüm)
local function Malzeme(ad, kaynak, toplamali)
     local m = CreateMaterial(ad, "UnlitGeneric", {
          ["$basetexture"] = "color/white",
          ["$vertexcolor"] = "1",
          ["$vertexalpha"] = "1",
          ["$translucent"] = toplamali and "0" or "1",
          ["$additive"] = toplamali and "1" or "0",
          ["$ignorez"] = "1"
     })
     local t = Material(kaynak):GetTexture("$basetexture")
     if t and not t:IsError() then m:SetTexture("$basetexture", t) end
     return m
end
local mSolOpak = Malzeme("SardonDuyuruGradL", "vgui/gradient-l")   -- solda opak, sağa söner
local mSagOpak = Malzeme("SardonDuyuruGradR", "vgui/gradient-r")   -- sağda opak, sola söner
local mIsik = Malzeme("SardonDuyuruIsik", "sprites/glow04_noz", true)

/*
*   Yazı tipleri: 1080p boyu × ScrH/1080. Türkçe metin 16 px altında harf aralığı bozuluyor →
*   gövde/imza en az 16 px; harf aralıklı büyük harf etiketleri harf harf çizildiği için 12 px'e iner.
*/
local AILE = {
     etiket = { "Montserrat SemiBold", 600, 12 },
     imza = { "Montserrat Medium", 500, 16 },
     baslik = { "Cinzel SemiBold", 600, 18 },
     govde = { "Montserrat Medium", 500, 16 },
     sayac = { "Montserrat SemiBold", 600, 16 },
}
local fontlar = {}
local function F(tur, boy)
     local a = AILE[tur]
     local px = math_max(a[3], math_Round(boy * ekranH / 1080))
     local ad = "SardonDuyuru." .. tur .. px
     if not fontlar[ad] then
          surface.CreateFont(ad, { font = a[1], size = px, weight = a[2], extended = true, antialias = true })
          fontlar[ad] = true
     end
     return ad
end

/*
*   Yazı yardımcıları
*/
local function Gen(metin, font)
     surface_SetFont(font)
     return surface_GetTextSize(metin)
end

-- y: satır ortası; hiza 0 sol, 1 orta, 2 sağ
local function Golgeli(metin, font, x, y, renk, a, hiza)
     surface_SetFont(font)
     local w, h = surface_GetTextSize(metin)
     local px = math_Round(x - (hiza == 1 and w / 2 or (hiza == 2 and w or 0)))
     local py = math_Round(y - h / 2)
     surface_SetTextColor(0, 0, 0, 190 * a)
     surface_SetTextPos(px + 1, py + 1)
     surface_DrawText(metin)
     surface_SetTextColor(renk.r, renk.g, renk.b, (renk.a or 255) * a)
     surface_SetTextPos(px, py)
     surface_DrawText(metin)
     return w
end

local function AralikliGen(metin, font, aralik)
     surface_SetFont(font)
     local w, n = 0, 0
     for _, kod in utf8.codes(metin) do
          w = w + surface_GetTextSize(utf8.char(kod))
          n = n + 1
     end
     return w + aralik * math_max(0, n - 1)
end

-- harf harf (küçük boyda Türkçe büyük harfler de düzgün aralıklı); x sol kenar, y satır ortası
local function Aralikli(metin, font, x, y, renk, a, aralik)
     surface_SetFont(font)
     local _, h = surface_GetTextSize("ÂÇ")
     local py = math_Round(y - h / 2)
     local cx = x
     for _, kod in utf8.codes(metin) do
          local c = utf8.char(kod)
          local px = math_Round(cx)
          surface_SetTextColor(0, 0, 0, 180 * a)
          surface_SetTextPos(px + 1, py + 1)
          surface_DrawText(c)
          surface_SetTextColor(renk.r, renk.g, renk.b, 255 * a)
          surface_SetTextPos(px, py)
          surface_DrawText(c)
          cx = cx + surface_GetTextSize(c) + aralik
     end
end

local SON_HARF = "[%z\1-\127\194-\244][\128-\191]*$"

local function Kirp(metin, font, w)
     surface_SetFont(font)
     if surface_GetTextSize(metin) <= w then return metin end
     while metin ~= "" and surface_GetTextSize(metin .. "…") > w do metin = metin:gsub(SON_HARF, "") end
     return metin .. "…"
end

-- tek başına satıra sığmayan kelime (bağlantı vb.) harf sınırında bölünür
local function KelimeBol(kelime, genislik)
     local parca, cikti = "", {}
     for _, kod in utf8.codes(kelime) do
          local c = utf8.char(kod)
          if parca ~= "" and surface_GetTextSize(parca .. c) > genislik then
               cikti[#cikti + 1] = parca
               parca = c
          else
               parca = parca .. c
          end
     end
     if parca ~= "" then cikti[#cikti + 1] = parca end
     return cikti
end

local function Sar(metin, font, genislik, enCok)
     surface_SetFont(font)
     local satirlar = {}
     local ok = pcall(function()
          for paragraf in (metin .. "\n"):gmatch("(.-)\n") do
               local satir = ""
               for kelime in paragraf:gmatch("%S+") do
                    local deneme = satir == "" and kelime or (satir .. " " .. kelime)
                    if surface_GetTextSize(deneme) <= genislik then
                         satir = deneme
                    else
                         if satir ~= "" then satirlar[#satirlar + 1] = satir end
                         if surface_GetTextSize(kelime) > genislik then
                              local p = KelimeBol(kelime, genislik)
                              for i = 1, #p - 1 do satirlar[#satirlar + 1] = p[i] end
                              satir = p[#p] or ""
                         else
                              satir = kelime
                         end
                    end
               end
               satirlar[#satirlar + 1] = satir
          end
     end)
     if not ok then satirlar = { metin } end
     while #satirlar > 1 and satirlar[#satirlar] == "" do table.remove(satirlar) end
     if enCok and #satirlar > enCok then
          for i = #satirlar, enCok + 1, -1 do satirlar[i] = nil end
          local son = satirlar[enCok]
          while son ~= "" and surface_GetTextSize(son .. "…") > genislik do son = son:gsub(SON_HARF, "") end
          satirlar[enCok] = son .. "…"
     end
     return satirlar
end

/*
*   Şekiller
*/
local elmasK = { { x = 0, y = 0 }, { x = 0, y = 0 }, { x = 0, y = 0 }, { x = 0, y = 0 } }
local function Elmas(cx, cy, r, c, a)
     elmasK[1].x, elmasK[1].y = cx, cy - r
     elmasK[2].x, elmasK[2].y = cx + r, cy
     elmasK[3].x, elmasK[3].y = cx, cy + r
     elmasK[4].x, elmasK[4].y = cx - r, cy
     draw_NoTexture()
     surface_SetDrawColor(c.r, c.g, c.b, a)
     surface_DrawPoly(elmasK)
end

local function ElmasUc(cx, cy, r, T, a)
     Elmas(cx, cy, r, T.renk, a)
     Elmas(cx, cy, r - math_max(1, O(1.3)), KOYU, a)
     Elmas(cx, cy, r * .46, T.acik, a)
end

-- ortası parlak, iki ucu sönen yatay çizgi; cx orta
local function Cizgi(cx, y, w, c, a)
     if w <= 0 then return end
     local yarim = w / 2
     local k = math_max(1, math_floor(O(1)))
     surface_SetDrawColor(c.r, c.g, c.b, a)
     surface_SetMaterial(mSolOpak)
     surface_DrawTexturedRect(cx, y, yarim, k)
     surface_SetMaterial(mSagOpak)
     surface_DrawTexturedRect(cx - yarim, y, yarim, k)
end

-- ortası opak, iki yana sönen; üst ve alt kenarı dilimlerle yumuşayan sis
local function Sis(ox, oy, W, H, s, a, kanat)
     local kw = math_floor(math_min(kanat, W * .32))
     local f = math_floor(math_min(O(12), H * .25))
     local adim = math_max(1, math_floor(f / 5 + .5))
     local function Serit(y, h, al)
          surface_SetDrawColor(s[1], s[2], s[3], al)
          surface_SetMaterial(mSagOpak)
          surface_DrawTexturedRect(ox, y, kw, h)
          surface_SetMaterial(mSolOpak)
          surface_DrawTexturedRect(ox + W - kw, y, kw, h)
          surface_DrawRect(ox + kw, y, W - 2 * kw, h)
     end
     local yy = 0
     while yy < f do
          local hh = math_min(adim, f - yy)
          local al = a * Yum((yy + hh * .5) / f)
          Serit(oy + yy, hh, al)
          Serit(oy + H - yy - hh, hh, al)
          yy = yy + hh
     end
     Serit(oy + f, H - 2 * f, a)
end

/*
*   BANT
*   v = { id, tur, baslik, metin, imza, sayac = bool, bitisRT, ses, sure }; Duzen ölçüleri v'ye yazar
*   (çözünürlük değişince yeniden).
*/
local function Duzen(v)
     local sw, sh = ScrW(), ScrH()
     if v.olcuW == sw and v.olcuH == sh then return end
     v.olcuW, v.olcuH = sw, sh
     local T = D.Tur[v.tur] or D.Tur.duyuru
     v.T = T

     v.fEtiket, v.fImza, v.fBaslik, v.fGovde = F("etiket", 14), F("imza", 16), F("baslik", 30), F("govde", 19)
     v.fSayacE, v.fSayac = F("etiket", 12), F("sayac", 24)
     v.aralik = O(4)

     local maxW = math_min(O(760), sw - O(200))
     v.etW = AralikliGen(T.etiket, v.fEtiket, v.aralik)
     v.imzaYazi = (v.imza or "") ~= "" and ("·  " .. v.imza) or ""
     v.imzaW = v.imzaYazi ~= "" and Gen(v.imzaYazi, v.fImza) or 0
     v.ustW = v.etW + (v.imzaW > 0 and O(12) + v.imzaW or 0)
     v.basliklar = (v.baslik or "") ~= "" and Sar(v.baslik, v.fBaslik, maxW, 2) or {}
     v.satirlar = Sar(v.metin or "", v.fGovde, maxW, 6)

     local icW = v.ustW
     for _, s in ipairs(v.basliklar) do icW = math_max(icW, Gen(s, v.fBaslik)) end
     for _, s in ipairs(v.satirlar) do icW = math_max(icW, Gen(s, v.fGovde)) end
     if v.sayac then
          v.kalanW = AralikliGen("KALAN SÜRE", v.fSayacE, O(3))
          icW = math_max(icW, (v.kalanW + O(10)) * 2 + Gen("0:00:00", v.fSayac))
     end
     v.icW = math_max(icW, O(300))

     -- dikey yerleşim (satır ortaları)
     local y = O(20)
     v.yUst = y + O(8)
     y = y + O(18)
     if v.basliklar[1] then
          y = y + O(8)
          v.yBaslik = y
          y = y + #v.basliklar * O(37)
     end
     y = y + O(10)
     v.yCizgi = math_floor(y + O(6))
     y = y + O(16)
     v.yGovde = y
     v.satirH = O(26)
     y = y + #v.satirlar * v.satirH
     if v.sayac then
          y = y + O(8)
          v.ySayac = y + O(15)
          y = y + O(30)
     end
     y = y + O(20)
     v.H = math_ceil(y)
     v.W = math_ceil(math_min(v.icW + O(300), sw))
end

-- durağan kısım; (ox, oy) bandın sol üstü; a: 0..1 (pişirmede 1)
local function BantIcerik(v, ox, oy, a)
     local T, W, H = v.T, v.W, v.H
     local cx = ox + W / 2
     Sis(ox, oy, W, H, T.sis, 226 * a, O(150))
     Cizgi(cx, oy, W * .62, T.renk, 80 * a)
     Cizgi(cx, oy + H - math_max(1, math_floor(O(1))), W * .62, T.renk, 60 * a)

     local x = cx - v.ustW / 2
     Aralikli(T.etiket, v.fEtiket, x, oy + v.yUst, T.renk, a, v.aralik)
     if v.imzaW > 0 then Golgeli(v.imzaYazi, v.fImza, x + v.etW + O(12), oy + v.yUst, SOLUK, a, 0) end

     for i, s in ipairs(v.basliklar) do
          Golgeli(s, v.fBaslik, cx, oy + v.yBaslik + (i - .5) * O(37), FILDISI, a, 1)
     end
     for i, s in ipairs(v.satirlar) do
          Golgeli(s, v.fGovde, cx, oy + v.yGovde + (i - .5) * v.satirH, YAZI, a, 1)
     end
     if v.sayac then
          Aralikli("KALAN SÜRE", v.fSayacE, cx - O(10) - v.kalanW, oy + v.ySayac, SOLUK, a, O(3))
     end
end

-- canlı kısım: açılan ayraç + elmas, giriş ışığı, sayaç, kalan süre ışığı; sabit = önizleme (oturmuş hâl)
local function BantCanli(v, ox, oy, a, simdi, sabit)
     local T, H = v.T, v.H
     local cx = ox + v.W / 2
     local gg = sabit and 99 or (simdi - v.bas)

     local cy = oy + v.yCizgi
     Cizgi(cx, cy, (v.icW * .9) * Yum(gg / .9) + O(30), T.renk, 210 * a)
     local vurgu = sabit and 0 or (1 - Yum(gg / .9))
     if vurgu > 0 then
          local gs = O(80) * (.6 + .4 * vurgu)
          surface_SetMaterial(mIsik)
          surface_SetDrawColor(T.renk.r, T.renk.g, T.renk.b, 170 * vurgu * a)
          surface_DrawTexturedRect(cx - gs / 2, cy - gs / 2, gs, gs)
     end
     ElmasUc(cx, cy, O(6) * (1 + .45 * vurgu), T, 255 * a)

     if not sabit then
          local sp = (gg - .2) / 1.1
          if sp > 0 and sp < 1 then
               local sx = cx - v.ustW / 2 - O(40) + (v.ustW + O(80)) * Yum(sp)
               surface_SetMaterial(mIsik)
               surface_SetDrawColor(T.acik.r, T.acik.g, T.acik.b, math_sin(sp * math_pi) * 80 * a)
               surface_DrawTexturedRect(sx - O(60), oy + v.yUst - O(24), O(120), O(48))
          end
     end

     if v.sayac then
          local kalan = sabit and (v.onizlemeKalan or 0) or ((v.bitisRT or 0) - simdi)
          local yazi = kalan > 0 and D.SayacYazi(kalan) or "ŞİMDİ"
          local nabiz = kalan > 0 and kalan <= 60 and (.75 + .25 * math_sin(simdi * 6)) or 1
          Golgeli(yazi, v.fSayac, cx + O(10), oy + v.ySayac, T.acik, a * nabiz, 0)
     end

     local oran = sabit and 1 or (v.cikis and 0 or math_Clamp((v.bitis - simdi) / v.sure, 0, 1))
     if oran > 0 then Cizgi(cx, oy + H - O(10), v.icW * oran, T.renk, 150 * a) end
end

-- bandın ekrandaki üst kenarı: Legacy'de pusula + bölge adının altı
local function UstY()
     local H = SardonHUD
     local L = H and H.Legacy
     local y = O(36)
     if L and L.S and H.LegacySecili and H.LegacySecili() and not (H.Gizli and H.Gizli()) then
          local lp = LocalPlayer()
          if IsValid(lp) and lp.GetCharacter and lp:GetCharacter() then y = math_max(y, L.S(29)) end
     end
     return math_floor(y)
end

local function Kuyrukla(v)
     for i = #D.Kuyruk, 1, -1 do
          if D.Kuyruk[i].id == v.id then table.remove(D.Kuyruk, i) end
     end
     D.Kuyruk[#D.Kuyruk + 1] = v
     local b = D.Bant
     if b and not b.cikis and b.bas then
          b.bitis = math_min(b.bitis, math_max(RealTime(), b.bas + 4))
     end
end

local function BantCiz(simdi, fx, fy)
     local v = D.Bant
     if v and v.cikis and simdi - v.cikis >= .55 then
          D.Bant, v = nil, nil
     end
     if not v then
          v = table.remove(D.Kuyruk, 1)
          if not v then return nil end
          v.bas, v.bitis = simdi, simdi + v.sure
          D.Bant = v
          local T = D.Tur[v.tur] or D.Tur.duyuru
          if v.ses then surface.PlaySound(T.ses) end
     end
     Duzen(v)
     if not v.cikis and simdi >= v.bitis then v.cikis = simdi end

     local gg = simdi - v.bas
     local a = Yum(gg / .45)
     local dy = -O(14) * (1 - Sonum(gg / .7))
     if v.cikis then
          local cg = simdi - v.cikis
          a = a * (1 - Yum(cg / .5))
          dy = dy - O(10) * Yum(cg / .5)
     end
     local x = math_floor(ScrW() / 2 - v.W / 2)
     local y = math_floor(UstY() + dy + .5)

     -- imleç bandın okunan ortasındaysa altındaki menü görünsün
     local ustte = fx and fx >= x + O(110) and fx <= x + v.W - O(110) and fy >= y and fy <= y + v.H
     v.hover = math_Approach(v.hover or 1, ustte and .14 or 1, FrameTime() * 5)
     a = a * v.hover
     if a > .01 then
          local L = Legacy()
          if L then
               if not v.k or v.pisW ~= v.olcuW or v.pisH ~= v.olcuH or simdi - (v.pisT or 0) > 2 then
                    v.k = L.Katman("duyuru_bant", v.W, v.H)
                    L.KatmanCiz(v.k, BantIcerik, v, 0, 0, 1)
                    v.pisW, v.pisH, v.pisT = v.olcuW, v.olcuH, simdi
               end
               L.KatmanBas(v.k, x, y, v.W, v.H, 255 * a)
          else
               BantIcerik(v, x, y, a)
          end
          BantCanli(v, x, y, a, simdi, false)
     end
     return y + v.H, v
end

/*
*   ŞERİT (geri sayım): bant kapanınca pusula altında kalır
*/
local function SeritDuzen(c, saatli)
     local sw, sh = ScrW(), ScrH()
     if c.olcuW == sw and c.olcuH == sh and c.saatli == saatli then return end
     c.olcuW, c.olcuH, c.saatli = sw, sh, saatli
     local T = D.Tur[c.tur] or D.Tur.duyuru
     c.T = T
     c.fEt, c.fAd, c.fSa = F("etiket", 11), F("govde", 16), F("sayac", 17)
     c.ar = O(3)
     c.etW = AralikliGen(T.etiket, c.fEt, c.ar)
     local ad = (c.baslik or "") ~= "" and c.baslik or ((c.metin or ""):match("^[^\n]*") or "")
     c.ad = Kirp(ad, c.fAd, O(340))
     c.adW = Gen(c.ad, c.fAd)
     c.saW = math_max(Gen(saatli and "0:00:00" or "00:00", c.fSa), Gen("ŞİMDİ", c.fSa))
     c.icW = O(16) + c.etW + O(14) + c.adW + O(18) + c.saW
     c.H = math_ceil(O(34))
     c.W = math_ceil(c.icW + O(220))
end

local function SeritIcerik(c, ox, oy, a)
     local T = c.T
     Sis(ox, oy, c.W, c.H, T.sis, 200 * a, O(110))
     local x0 = ox + (c.W - c.icW) / 2
     local cy = oy + c.H / 2
     ElmasUc(x0 + O(5), cy, O(4.6), T, 255 * a)
     Aralikli(T.etiket, c.fEt, x0 + O(16), cy, T.renk, a, c.ar)
     Golgeli(c.ad, c.fAd, x0 + O(16) + c.etW + O(14), cy, YAZI, a, 0)
end

local function SeritCiz(c, yuva, y, simdi, fx, fy)
     local kalan = c.bitisRT - simdi
     SeritDuzen(c, kalan >= 3600)
     c.gor = c.gor or simdi
     local a = Yum((simdi - c.gor) / .4)
     if c.sifirT then a = a * (1 - Yum((simdi - c.sifirT - 6) / .8)) end
     local x = math_floor(ScrW() / 2 - c.W / 2)
     -- menü açıkken (imleç görünür: TAB menüsü, envanter...) şerit menünün üst çubuğunu örtmesin;
     -- son dakika ve "ŞİMDİ" yine tam görünür. İmleç üstündeyse iyice saydamlaşır.
     local hedef = 1
     if fx then
          if kalan > 60 then hedef = .3 end
          if fx >= x + O(80) and fx <= x + c.W - O(80) and fy >= y and fy <= y + c.H then hedef = .1 end
     end
     c.sol = math_Approach(c.sol or 1, hedef, FrameTime() * 4)
     a = a * c.sol
     if a <= .01 then return c.H end

     local L = Legacy()
     if L then
          if not c.k or c.pisW ~= c.olcuW or c.pisH ~= c.olcuH or c.pisS ~= c.saatli or c.pisY ~= yuva or simdi - (c.pisT or 0) > 2 then
               c.k = L.Katman("duyuru_serit" .. yuva, c.W, c.H)
               L.KatmanCiz(c.k, SeritIcerik, c, 0, 0, 1)
               c.pisW, c.pisH, c.pisS, c.pisY, c.pisT = c.olcuW, c.olcuH, c.saatli, yuva, simdi
          end
          L.KatmanBas(c.k, x, y, c.W, c.H, 255 * a)
     else
          SeritIcerik(c, x, y, a)
     end

     local sx = x + (c.W - c.icW) / 2 + c.icW - c.saW
     local yazi = kalan > 0 and D.SayacYazi(kalan) or "ŞİMDİ"
     local nabiz = (kalan <= 60) and (.7 + .3 * math_sin(simdi * 6)) or 1
     Golgeli(yazi, c.fSa, sx, y + c.H / 2, c.T.acik, a * nabiz, 0)
     return c.H
end

-- 5 ve 1 dakika kala bant yeniden; süre dolunca ses + "ŞİMDİ"
local function Hatirlat(c, simdi)
     local b = D.Bant
     if b and b.id == c.id and not b.cikis then return end
     Kuyrukla({ id = c.id, tur = c.tur, baslik = c.baslik, metin = c.metin, imza = c.imza, sayac = true,
          bitisRT = c.bitisRT, ses = true, sure = 9 })
end

local function SayaclariIlerlet(simdi)
     for id, c in pairs(D.Sayaclar) do
          local kalan = c.bitisRT - simdi
          if c.hat1 and kalan <= 60 then
               c.hat1, c.hat5 = false, false
               Hatirlat(c, simdi)
          elseif c.hat5 and kalan <= 300 then
               c.hat5 = false
               Hatirlat(c, simdi)
          end
          if kalan <= 0 and not c.sifirT then
               c.sifirT = simdi
               local T = D.Tur[c.tur] or D.Tur.duyuru
               surface.PlaySound(T.ses)
          end
          if c.sifirT and simdi - c.sifirT > 7 then D.Sayaclar[id] = nil end
     end
end

local sonAlt, sonAltKare = 0, -9

-- görev afişi/bildirimi gibi üst ortadaki öğeler bunun altına iner ([sardon] gorev cl_5hud)
function D.Alt()
     if FrameNumber() - sonAltKare > 3 then return 0 end
     return sonAlt
end

local function Ciz()
     if not D.Bant and not D.Kuyruk[1] and next(D.Sayaclar) == nil then return end
     EkranOku()
     local simdi = RealTime()
     SayaclariIlerlet(simdi)

     local fx, fy
     if vgui.CursorVisible() then fx, fy = gui.MousePos() end

     local alt, bant = BantCiz(simdi, fx, fy)
     local y = alt and (alt + O(6)) or UstY()
     -- bant sönünce şeritler yukarı yumuşakça kayar
     local yaklas = 1 - math.exp(-math_min(FrameTime(), .1) * 10)
     local yuva = 0
     for id, c in pairs(D.Sayaclar) do
          if bant and bant.id == id and not bant.cikis then
               c.gor, c.y = nil, nil   -- bant kapanınca şerit yeniden belirsin
          elseif yuva < 3 then
               yuva = yuva + 1
               c.y = c.y and c.y + (y - c.y) * yaklas or y
               y = y + SeritCiz(c, yuva, math_floor(c.y + .5), simdi, fx, fy) + O(4)
          end
     end
     sonAlt, sonAltKare = math_max(y, alt or 0), FrameNumber()
end

D.Ciz = Ciz
hook.Add("PostRenderVGUI", "SardonDuyuru", function()
     local ok, hata = pcall(Ciz)
     if not ok then
          ErrorNoHalt("[SardonDuyuru] " .. tostring(hata) .. "\n")
          D.Bant = nil
          table.Empty(D.Kuyruk)
     end
end)

/*
*   Gelen duyuru
*/
local function SohbetSatiri(k)
     local T = D.Tur[k.tur] or D.Tur.duyuru
     local govde = ((k.baslik or "") ~= "" and (k.baslik .. ": ") or "") .. (string.gsub(k.metin or "", "\n+", " "))
     local ek = (k.kalan or 0) > 0 and ("  (" .. D.DakikaYazi(math.ceil(k.kalan / 60)) .. " sonra)") or ""
     chat.AddText(T.renk, "[" .. T.ad .. "] ", YAZI, govde, SOLUK, ek .. "  · " .. ((k.imza or "") ~= "" and k.imza or "Yönetim"))
end

-- k = { id, tur, baslik, metin, imza, kalan (sn, 0 = geri sayım yok), ses, gec }; onizleme: yalnız bu ekranda bant
function D.Al(k, onizleme)
     if not D.Tur[k.tur] then k.tur = "duyuru" end
     local simdi = RealTime()
     local kalan = k.kalan or 0
     if kalan > 0 and not onizleme then
          D.Sayaclar[k.id] = { id = k.id, tur = k.tur, baslik = k.baslik, metin = k.metin, imza = k.imza,
               bitisRT = simdi + kalan, hat5 = kalan > 330, hat1 = kalan > 90 }
     end
     if not k.gec and not onizleme then SohbetSatiri(k) end
     Kuyrukla({ id = k.id, tur = k.tur, baslik = k.baslik, metin = k.metin, imza = k.imza,
          sayac = kalan > 0, bitisRT = kalan > 0 and simdi + kalan or nil,
          ses = k.ses and not k.gec, sure = k.gec and 9 or D.Sure(k.baslik, k.metin) })
end

-- id 0: hepsi
function D.Sil(id)
     local simdi = RealTime()
     if id == 0 then
          table.Empty(D.Sayaclar)
          table.Empty(D.Kuyruk)
          if D.Bant and not D.Bant.cikis then D.Bant.cikis = simdi end
          return
     end
     D.Sayaclar[id] = nil
     for i = #D.Kuyruk, 1, -1 do
          if D.Kuyruk[i].id == id then table.remove(D.Kuyruk, i) end
     end
     if D.Bant and D.Bant.id == id and not D.Bant.cikis then D.Bant.cikis = simdi end
end

/*
*   Shine sayfası önizlemesi: bandı verilen yere oturmuş hâliyle çizer (cl_2sayfa).
*   t = { tur, baslik, metin, imza, dk }; dönüş: bandın ölçüleri (W, H) için v
*/
function D.Onizleme(t)
     EkranOku()
     local v = { id = -1, tur = t.tur, baslik = t.baslik, metin = t.metin, imza = t.imza, sayac = (t.dk or 0) > 0, onizlemeKalan = (t.dk or 0) * 60 }
     Duzen(v)
     return v
end

function D.OnizlemeCiz(v, x, y)
     EkranOku()
     Duzen(v)
     BantIcerik(v, x, y, 1)
     BantCanli(v, x, y, 1, RealTime(), true)
end

/*
*   Ağ
*/
net.Receive(D.NET, function()
     local islem = net.ReadUInt(3)
     if islem == 1 then
          D.Al({
               id = net.ReadUInt(32), tur = net.ReadString(), baslik = net.ReadString(), metin = net.ReadString(),
               imza = net.ReadString(), kalan = net.ReadUInt(16), ses = net.ReadBool(), gec = net.ReadBool(),
          })
     elseif islem == 2 then
          D.Sil(net.ReadUInt(32))
     elseif islem == 3 then
          local n = net.ReadUInt(32)
          local d = n > 0 and util.Decompress(net.ReadData(n)) or nil
          local t = d and util.JSONToTable(d)
          if istable(t) then
               D.SayfaVeri, D.SayfaVeriT = t, RealTime()
               if D.SayfaYenile then
                    local ok, hata = pcall(D.SayfaYenile)
                    if not ok then ErrorNoHalt("[SardonDuyuru] sayfa: " .. tostring(hata) .. "\n") end
               end
          end
     elseif islem == 4 then
          local ok, mesaj = net.ReadBool(), net.ReadString()
          if D.SayfaSonuc then pcall(D.SayfaSonuc, ok, mesaj) end
     end
end)

-- sunucuya "hazırım": süren geri sayımlar gelir; gelmeyen istemci duyuruyu sohbet satırı olarak alır
local function Hazir()
     if not IsValid(LocalPlayer()) then return false end
     net.Start(D.NET)
          net.WriteUInt(1, 3)
     net.SendToServer()
     return true
end
if not Hazir() then
     timer.Create("SardonDuyuru.Hazir", 1, 180, function()
          if Hazir() then timer.Remove("SardonDuyuru.Hazir") end
     end)
end
