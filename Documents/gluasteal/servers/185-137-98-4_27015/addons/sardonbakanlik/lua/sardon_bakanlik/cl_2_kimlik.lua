-- "addons\\sardonbakanlik\\lua\\sardon_bakanlik\\cl_2_kimlik.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Expediente :: Documento de identidad de mago, istemci.
--
-- Kart tasarımı: SHINE kompakt Ministerio kimliği (SHINE_Bakanlik_Kimlik_Menu_Tasarimi; ~/araclar/kimlik/tasarim).
-- 600x350 tasarım px: solda yeşil güvenlik şeridi, kemerli portre, fildişi baskı alanı, M filigranı.
--   zemin           şekiller, degradeler, kemer çerçevesi ve Cinzel başlık 2x pişmiş JPEG (dosya sonundaki
--                   gömülü dokular, uret.py); değişen yazılar burada Georgia / Arial ile çizilir
--   pişirme         K.YuzPisir: zemin + yazılar → opak yüz RT'si (kart başına bir kez)
--                   K.SonCiz: yüz RT'si yuvarlak köşeli çokgenle saydam hedefe + kemerli portre + folyo parıltısı
--   gösterim        "kimlik.kart" / "kimlik.zorla": kart; portre canlı (PostRender'da RT'ye), K / mühür ile
--                   650 ms perspektifli çevirme (dikey şeritler), Esc / köşe halkası kapatır. Yetkili görürse
--                   yanında sorgu kartı.
--   istem           "kimlik.istem": agente kimlik istedi, kart seç ya da reddet (20 s)
--   tuşlar          Tuş Atamaları › "[Kimlik] Kartı çevir" (varsayılan K). İmleçli kipte panel MakePopup'tır
--                   (klavye oyunda kalır): Helix menüsü / sohbet kapanırken gui.EnableScreenClicker(false) çağırıyor.
--   sahte           envanterde "Rellenar": Gölge'nin boş belgesini doldurma formu
--   sayfa           defter › "Identidad y padrón" (Gişe'den de açılır)
-- Paneller B.UI araç takımını kendi ölçekleriyle kullanır; her çizimin başında U'nun paylaşılan durumunu
-- kaydeder, sonunda geri koyar (defter aynı anda açık olabilir).

local B = SardonBakanlik
local K = B.Kimlik
local A = K.Ayar
local U = B.UI
local R = U.R

local CW, CH = 600, 350
K.CW, K.CH = CW, CH
local POR = {x = 18, y = 69, w = 125, h = 125 * 196 / 154}  -- kemerli portre penceresi

local function Hex(h, a)
     return Color(tonumber(string.sub(h, 1, 2), 16), tonumber(string.sub(h, 3, 4), 16), tonumber(string.sub(h, 5, 6), 16), math.Round((a or 1) * 255))
end

-- styles.css renkleri
local T = {
     baslik = Hex("2b3c29"), alt = Hex("6f704f"), etiket = Hex("747451"), ad = Hex("21351f"), deger = Hex("2d3b26"),
     belge = Hex("3a442c"), not_ = Hex("86805b"), h2 = Hex("2b3d26"), bos = Hex("68704d"), protean = Hex("4b573a"),
     no = Hex("3b492e"), monogram = Hex("dac086"), filigran = Hex("506846"), folyo = Hex("b29350"), parilti = Hex("eed798"),
     arma = Hex("ceb678"), cizgi = Hex("897f4c"), kizil = Hex("8e2a22"), altin = Hex("b69b61"), kagit = Hex("e6d9b2"),
     muhurYazi = Hex("eee1bb"), tus = Hex("bca875"), halka = Hex("c7ae75"), halkaZemin = Hex("173327"), halkaUstu = Hex("31523b"),
     carpi = Hex("e7d7ad"), nokta = Hex("486047"), noktaSoluk = Hex("a8a076", 0.45), ilerleme = Hex("777554"),
     serit1 = Hex("173327"), serit2 = Hex("0f231b"), panelYazi = Hex("e9d9ac"), panelSoluk = Hex("bca875"), portre = Hex("9c956f"),
     siyah = Color(0, 0, 0),
}
K.Renk = T

K.ekX, K.ekY = 0, 0

----------------------------------------------------------------------------------------
-- U durumunu kaydet / geri koy (küçük pencereler U araç takımını kendi ölçeğiyle kullanır)
----------------------------------------------------------------------------------------
local ALANLAR = {"S", "OX", "OY", "fareX", "fareY", "tik", "teker", "engel", "klip", "imlec", "ipucu", "panel"}

local function Sakla()
     local t = {}
     for i, k in ipairs(ALANLAR) do t[i] = U[k] end
     return t
end

local function GeriKoy(t)
     for i, k in ipairs(ALANLAR) do U[k] = t[i] end
end

local function GorunenAd(p)
     if not IsValid(p) then return "Biri" end
     local ad = hook.Run("GetCharacterName", p)
     if isstring(ad) and ad ~= "" then return ad end
     local c = p.GetCharacter and p:GetCharacter()
     return c and c:GetName() or p:Nick()
end
K.GorunenAd = GorunenAd

local function Tarih(t) return B.Tarih(t, false) end

----------------------------------------------------------------------------------------
-- RT'ler
----------------------------------------------------------------------------------------
K.RT = K.RT or {}

local function RTYap(ad, w, h, derin)
     if K.RT[ad] then return K.RT[ad] end
     local rt = GetRenderTargetEx(ad, w, h, RT_SIZE_LITERAL, derin and MATERIAL_RT_DEPTH_SEPARATE or MATERIAL_RT_DEPTH_NONE, bit.bor(4, 8), 0, IMAGE_FORMAT_RGBA8888)
     local t = {
          rt = rt, w = w, h = h,
          ui = CreateMaterial(ad .. "_ui", "UnlitGeneric", {["$basetexture"] = rt:GetName(), ["$vertexcolor"] = 1, ["$vertexalpha"] = 1, ["$translucent"] = 1}),
          dunya = CreateMaterial(ad .. "_dn", "UnlitGeneric", {["$basetexture"] = rt:GetName(), ["$vertexcolor"] = 1}),
     }
     K.RT[ad] = t
     return t
end
K.RTYap = RTYap

-- RT gestionai bir sonraki PostRender'da yapılır (kanca yalnız iş varken)
local isler = {}

local function IsleriYap()
     local liste = isler
     isler = {}
     for _, fn in ipairs(liste) do
          local ok, hata = pcall(fn)
          if not ok then ErrorNoHalt("[Sardon Ministerio] kimlik RT: " .. tostring(hata) .. "\n") end
     end
     if #isler == 0 then hook.Remove("PostRender", "SardonBakanlik.KimlikRT") end
end

function K.IsEkle(fn)
     isler[#isler + 1] = fn
     hook.Add("PostRender", "SardonBakanlik.KimlikRT", IsleriYap)
end

-- 2B çizimi opak RT'ye yap: alfa 255 kalsın (yazı kenarları kartı delmesin)
function K.RTCiz(hedef, fn, zemin)
     zemin = zemin or T.kagit
     render.PushRenderTarget(hedef.rt)
     render.Clear(zemin.r, zemin.g, zemin.b, 255, true, true)
     cam.Start2D()
     render.OverrideAlphaWriteEnable(true, false)
     local u = Sakla()
     local ok, hata = pcall(fn)
     GeriKoy(u)
     render.OverrideAlphaWriteEnable(false)
     cam.End2D()
     render.PopRenderTarget()
     if not ok then error(hata, 0) end
end

----------------------------------------------------------------------------------------
-- Çizim hedefi: ölçek (px / tasarım px) ve ofset. RT'de ofset 0, panelde kartın sol üstü.
----------------------------------------------------------------------------------------
local Z = {k = 1, ox = 0, oy = 0}
local function Hedef(k, ox, oy) Z.k, Z.ox, Z.oy = k, ox or 0, oy or 0 end
local function PX(x) return Z.ox + x * Z.k end
local function PY(y) return Z.oy + y * Z.k end

-- Yazı tipleri: "g" Georgia (kartın serif yazısı), "a" Arial, "ab" kalın Arial
local fontlar = {}
local function F(aile, px)
     px = math.max(8, math.Round(px))
     local ad = "SBKimlik2_" .. aile .. "_" .. px
     if not fontlar[ad] then
          surface.CreateFont(ad, {font = aile == "g" and "Georgia" or "Arial", size = px, weight = aile == "ab" and 700 or 400, antialias = true, extended = true})
          fontlar[ad] = true
     end
     return ad
end

-- Genişlik (tasarım px). aralik: harf arası (tasarım px); verilirse harf harf ölçülür
local function Olc(metin, aile, boy, aralik)
     metin = tostring(metin or "")
     surface.SetFont(F(aile, boy * Z.k))
     if not aralik or aralik == 0 then return (surface.GetTextSize(metin)) / Z.k end
     local w, n = 0, 0
     for _, kod in utf8.codes(metin) do
          w = w + surface.GetTextSize(utf8.char(kod))
          n = n + 1
     end
     return (w + aralik * Z.k * math.max(0, n - 1)) / Z.k
end

-- y satırın dikey ortası; hiza 0 sol, 1 orta, 2 sağ. Dönüş: genişlik (tasarım px)
local function Yaz(metin, aile, boy, x, y, renk, hiza, aralik, alfa)
     metin = tostring(metin or "")
     local w = Olc(metin, aile, boy, aralik)
     surface.SetFont(F(aile, boy * Z.k))
     local _, h = surface.GetTextSize("Ag")
     local px = PX(x) - (hiza == 1 and w * Z.k / 2 or (hiza == 2 and w * Z.k or 0))
     local py = math.Round(PY(y) - h / 2)
     surface.SetTextColor(renk.r, renk.g, renk.b, (alfa or 1) * renk.a)
     if not aralik or aralik == 0 then
          surface.SetTextPos(math.Round(px), py)
          surface.DrawText(metin)
     else
          local ara = aralik * Z.k
          for _, kod in utf8.codes(metin) do
               local c = utf8.char(kod)
               surface.SetTextPos(math.Round(px), py)
               surface.DrawText(c)
               px = px + surface.GetTextSize(c) + ara
          end
     end
     return w
end

local function Kisalt(metin, aile, boy, genislik)
     metin = tostring(metin or "")
     if Olc(metin, aile, boy) <= genislik then return metin end
     local harfler = {}
     for _, kod in utf8.codes(metin) do harfler[#harfler + 1] = utf8.char(kod) end
     for n = #harfler - 1, 1, -1 do
          local c = table.concat(harfler, "", 1, n) .. "…"
          if Olc(c, aile, boy) <= genislik then return c end
     end
     return "…"
end

local function Sar(metin, aile, boy, genislik)
     local satirlar, cur = {}, ""
     for kelime in string.gmatch(tostring(metin), "%S+") do
          local aday = cur == "" and kelime or (cur .. " " .. kelime)
          if cur ~= "" and Olc(aday, aile, boy) > genislik then
               satirlar[#satirlar + 1] = cur
               cur = kelime
          else
               cur = aday
          end
     end
     if cur ~= "" then satirlar[#satirlar + 1] = cur end
     return satirlar
end

local function Kutu(x, y, w, h, renk, alfa)
     surface.SetDrawColor(renk.r, renk.g, renk.b, (alfa or 1) * renk.a)
     surface.DrawRect(math.Round(PX(x)), math.Round(PY(y)), math.max(1, math.Round(w * Z.k)), math.max(1, math.Round(h * Z.k)))
end

----------------------------------------------------------------------------------------
-- Çokgenler (saat yönünde; tasarım px). PolyUV: u,v çokgenin kutusuna göre (dokuyu şekle kırpar)
----------------------------------------------------------------------------------------
local function Yay(p, cx, cy, rx, ry, a0, a1, n)
     for i = 0, n do
          local a = a0 + (a1 - a0) * i / n
          p[#p + 1] = {cx + math.cos(a) * rx, cy + math.sin(a) * ry}
     end
end

-- CSS border-radius: 48% 48% 20% 20% / 36% 36% 16% 16%
local function Kemer(x0, y0, w, h, genis, n)
     genis, n = genis or 0, n or 12
     x0, y0, w, h = x0 - genis, y0 - genis, w + 2 * genis, h + 2 * genis
     local rxu, ryu, rxa, rya = 0.48 * w, 0.36 * h, 0.20 * w, 0.16 * h
     local p = {}
     Yay(p, x0 + rxu, y0 + ryu, rxu, ryu, math.pi, 1.5 * math.pi, n)
     Yay(p, x0 + w - rxu, y0 + ryu, rxu, ryu, 1.5 * math.pi, 2 * math.pi, n)
     Yay(p, x0 + w - rxa, y0 + h - rya, rxa, rya, 0, 0.5 * math.pi, math.ceil(n / 2))
     Yay(p, x0 + rxa, y0 + h - rya, rxa, rya, 0.5 * math.pi, math.pi, math.ceil(n / 2))
     return p
end

local function Yuvarlak(x0, y0, w, h, r, n)
     n = n or 6
     local p = {}
     Yay(p, x0 + r, y0 + r, r, r, math.pi, 1.5 * math.pi, n)
     Yay(p, x0 + w - r, y0 + r, r, r, 1.5 * math.pi, 2 * math.pi, n)
     Yay(p, x0 + w - r, y0 + h - r, r, r, 0, 0.5 * math.pi, n)
     Yay(p, x0 + r, y0 + h - r, r, r, 0.5 * math.pi, math.pi, n)
     return p
end

local function PolyUV(noktalar, bx, by, bw, bh)
     local t = {}
     for i, p in ipairs(noktalar) do
          t[i] = {x = PX(p[1]), y = PY(p[2]), u = (p[1] - bx) / bw, v = (p[2] - by) / bh}
     end
     return t
end

local function Rellenar(noktalar, renk, alfa)
     draw.NoTexture()
     surface.SetDrawColor(renk.r, renk.g, renk.b, (alfa or 1) * renk.a)
     surface.DrawPoly(PolyUV(noktalar, 0, 0, 1, 1))
end

local function Daire(cx, cy, r, renk, alfa)
     local p = {}
     Yay(p, cx, cy, r, r, 0, 2 * math.pi, math.Clamp(math.ceil(r * Z.k * 0.7), 12, 48))
     p[#p] = nil
     Rellenar(p, renk, alfa)
end

local function Cember(cx, cy, r, renk, alfa, a0, a1, kalin)
     a0, a1 = a0 or 0, a1 or 2 * math.pi
     surface.SetDrawColor(renk.r, renk.g, renk.b, (alfa or 1) * renk.a)
     local n = math.max(8, math.ceil(math.abs(a1 - a0) * r * Z.k * 0.25))
     for k = 0, (kalin or 1) - 1 do
          local rr = r + k * 0.5
          local ox, oy
          for i = 0, n do
               local a = a0 + (a1 - a0) * i / n
               local x, y = PX(cx + math.cos(a) * rr), PY(cy + math.sin(a) * rr)
               if ox then surface.DrawLine(ox, oy, x, y) end
               ox, oy = x, y
          end
     end
end

local function Baklava(cx, cy, r, renk, alfa)
     Rellenar({{cx, cy - r}, {cx + r, cy}, {cx, cy + r}, {cx - r, cy}}, renk, alfa)
end

-- Cerrado çokgen çevresi; kalınlık tasarım px (hedef ölçeğinde birkaç piksel kaydırılarak)
local function Cevre(noktalar, renk, alfa, kalin)
     surface.SetDrawColor(renk.r, renk.g, renk.b, (alfa or 1) * renk.a)
     local n = math.max(1, math.Round((kalin or 1) * Z.k))
     for d = 0, n - 1 do
          local o = d - (n - 1) / 2
          for i = 1, #noktalar do
               local a, b = noktalar[i], noktalar[i % #noktalar + 1]
               surface.DrawLine(PX(a[1]) + o, PY(a[2]) + o, PX(b[1]) + o, PY(b[2]) + o)
          end
     end
end

local function Cizgi(x1, y1, x2, y2, renk, alfa, kalin)
     surface.SetDrawColor(renk.r, renk.g, renk.b, (alfa or 1) * renk.a)
     local n = math.max(1, math.Round((kalin or 1) * Z.k))
     for d = 0, n - 1 do
          surface.DrawLine(PX(x1) + d, PY(y1), PX(x2) + d, PY(y2))
     end
end

-- Kapsül etiket (ince çerçeveli). Dönüş: genişlik
local function Kapsul(metin, x, y, renk, hiza)
     local w = Olc(metin, "ab", 9.5, 0.9) + 14
     if hiza == 2 then x = x - w end
     surface.SetDrawColor(renk.r, renk.g, renk.b, 0.85 * renk.a)
     surface.DrawOutlinedRect(math.Round(PX(x)), math.Round(PY(y - 8)), math.Round(w * Z.k), math.Round(16 * Z.k), math.max(1, math.Round(Z.k)))
     Yaz(metin, "ab", 9.5, x + w / 2, y, renk, 1, 0.9)
     return w
end

----------------------------------------------------------------------------------------
-- Yüz pişirme: zemin dokusu + yazılar (opak RT; ölçek = rt.w / 600)
----------------------------------------------------------------------------------------
local function CasaYazi(kart)
     local hane = K.Casaler[kart.hane or 0]
     if not hane then return "—" end
     return hane .. ((kart.yil or 0) > 0 and (" · " .. kart.yil .. ".º curso") or "")
end

local ICERIK_X, ICERIK_W = 174, 403

local function OnYazilar(kart)
     Yaz("M", "g", 23, 75, 32.5, T.monogram, 1)
     Yaz("Registro Mágico de Población", "a", 11.5, ICERIK_X, 53, T.alt)
     if (kart.gorevli or "") ~= "" then Kapsul("FUNCIONARIO DEL MINISTERIO", 577, 31, T.altin, 2) end

     if kart.bos then
          Yaz("DOCUMENTO VACÍO", "g", 29, ICERIK_X, 121, T.kizil, 0, 2)
          Yaz("Documento sin sello ni cumplimentar.", "a", 13, ICERIK_X, 160, T.protean)
          Yaz("Documento enlazado por Protean", "a", 11, ICERIK_X, 331, T.not_)
          return
     end

     Yaz("Nombre y apellidos", "a", 12, ICERIK_X, 92, T.etiket)
     Yaz(Kisalt(kart.ad or "?", "g", 29, ICERIK_W), "g", 29, ICERIK_X, 121, T.ad, 0, -0.4)

     local hw = Yaz("Casa · Curso", "a", 12, ICERIK_X, 157, T.etiket)
     if kart.resit == false then Kapsul("MENOR DE EDAD", ICERIK_X + hw + 10, 157, T.kizil) end
     Yaz("Kan durumu", "a", 12, 388, 157, T.etiket)
     Yaz(Kisalt(CasaYazi(kart), "g", 19, 200), "g", 19, ICERIK_X, 182, T.deger)
     local kan = K.KanAd[kart.kan or ""]
     Yaz(kan or "—", "g", 19, 388, 182, T.deger)

     Yaz("Meslek", "a", 12, ICERIK_X, 211, T.etiket)
     local meslek = (kart.meslek or "") ~= "" and kart.meslek or "—"
     local mw = Yaz(Kisalt(meslek, "g", 19, ICERIK_W), "g", 19, ICERIK_X, 236, T.deger)
     if (kart.gorevli or "") ~= "" and mw < ICERIK_W - 40 then
          Yaz(Kisalt("· " .. kart.gorevli, "a", 12, ICERIK_W - mw - 10), "a", 12, ICERIK_X + mw + 8, 238, T.alt)
     end

     Yaz("Belge no", "a", 12, ICERIK_X, 278, T.etiket)
     Yaz(kart.no or "?", "a", 14, ICERIK_X, 300, T.belge, 0, 0.7)
     local tarih = Tarih(kart.verilis or 0)
     local sag = 577 - math.max(Olc("Expedición", "a", 12), Olc(tarih, "a", 14))
     Yaz("Expedición", "a", 12, sag, 278, T.etiket)
     Yaz(tarih, "a", 14, sag, 300, T.belge)

     Yaz("Documento enlazado por Protean", "a", 11, ICERIK_X, 331, T.not_, 0, 0.3)
end

local PROTEAN = {
     "Este documento está enlazado al expediente del Ministerio de Magia con el hechizo Protean: los cambios en el registro se reflejan solos en el documento.",
     "Quien lo encuentre debe entregarlo en la ventanilla del Ministerio más cercana.",
}

local function ArkaYazilar(kart)
     Yaz("M", "g", 23, 75, 32.5, T.monogram, 1)
     Yaz("M", "g", 86, 75, 138, T.arma, 1, 0, 0.36)
     Yaz("Registros y licenciaslar", "a", 11.5, ICERIK_X, 53, T.alt)
     Yaz("Ruhsatlar ve registroslar", "g", 23, ICERIK_X, 100, T.h2, 0, -0.3)

     local y = 132
     local liste = kart and kart.ruhsatlar or {}
     if #liste == 0 then
          Yaz("Sin licencias registradas.", "a", 15, ICERIK_X, y, T.bos)
          y = y + 22
     else
          for i, ad in ipairs(liste) do
               if i > 3 then
                    Yaz("+" .. (#liste - 3) .. " registros daha", "a", 13, ICERIK_X + 14, y, T.bos)
                    y = y + 20
                    break
               end
               Baklava(ICERIK_X + 4, y, 3.2, T.altin)
               Yaz(Kisalt(ad, "g", 16, ICERIK_W - 16), "g", 16, ICERIK_X + 14, y, T.deger)
               y = y + 22
          end
     end

     y = y + 4
     for j, p in ipairs(PROTEAN) do
          for _, s in ipairs(Sar(p, "a", 14, ICERIK_W)) do
               y = y + 10.5
               Yaz(s, "a", 14, ICERIK_X, y, T.protean)
               y = y + 10.5
          end
          if j < #PROTEAN then y = y + 8 end
     end

     y = math.min(y + 9, 296)
     Kutu(ICERIK_X, y, ICERIK_W, 1 / Z.k, T.cizgi, 0.25)
     if kart then Yaz(kart.no or "", "a", 15, ICERIK_X, y + 17, T.no, 0, 0.7) end

     Yaz("Documento enlazado por Protean", "a", 11, ICERIK_X, 331, T.not_, 0, 0.3)
end

-- Filigran: soluk yeşil + altın folyo (parıltı son çizimde)
local function Filigran()
     Yaz("M", "g", 142, 578, 208, T.filigran, 2, 0, 0.06)
     Yaz("M", "g", 142, 578, 208, T.folyo, 2, 0, 0.12)
end

-- Zeminin keskin çizgileri (degradeler kimlik2_zemin dokusunda): çerçeveler, şerit kenarları, monogram
-- halkası, başlık ve kemerli portre çerçevesi
local function ZeminCizgileri(arka)
     Cevre(Yuvarlak(8, 8, CW - 16, CH - 16, 11, 5), Hex("8d8052"), 0.16)
     Cevre(Yuvarlak(12, 12, 128, 326, 64, 8), Hex("cfb676"), 0.17)
     Cizgi(152, 0, 141.4, CH, Hex("b69b61"), 0.95)
     local parlak = Hex("d1af6d")
     Cizgi(149.2, 0, 145.7, 117, parlak, 0.52)
     Cizgi(145.7, 117, 142.2, 233, parlak, 0.12)
     Cizgi(142.2, 233, 138.7, CH, parlak, 0.52)
     Cember(75, 32, 17, Hex("c7aa6e"), 0.6)
     Cember(75, 32, 14.5, Hex("c7aa6e"), 0.08, nil, nil, 3)
     Cizgi(174, 71.5, 577, 71.5, Hex("897e4b"), 0.25)
     local baslik = B.Doku("kimlik2_baslik")
     local boyut = B.DokuBoyut and B.DokuBoyut["kimlik2_baslik"]
     if baslik and boyut then
          surface.SetMaterial(baslik)
          surface.SetDrawColor(T.baslik.r, T.baslik.g, T.baslik.b, 255)
          surface.DrawTexturedRect(PX(174), PY(19), boyut[1] / 2 * Z.k, boyut[2] / 2 * Z.k)
          draw.NoTexture()
     else
          Yaz("MINISTERIO DE MAGIA", "g", 17, 174, 30, T.baslik, 0, 1.2)
     end
     if not arka then
          Cizgi(174, 258.5, 577, 258.5, Hex("8b8045"), 0.17)
          local x0, y0, w, h = POR.x, POR.y, POR.w, POR.h
          for i = 1, 5 do Rellenar(Kemer(x0, y0 + 6, w, h, 7 + i * 1.6, 10), T.siyah, 0.05) end
          Rellenar(Kemer(x0, y0, w, h, 7, 12), Hex("122c1e"))
          Cevre(Kemer(x0, y0, w, h, 4.5, 14), Hex("e2c990"), 1)
          Rellenar(Kemer(x0, y0, w, h, 0, 14), T.portre)
     end
     Cevre(Yuvarlak(0.5, 0.5, CW - 1, CH - 1, 17, 6), Hex("d1bd85"), 1, 1.2)
end

function K.YuzPisir(rt, kart, arka)
     K.RTCiz(rt, function()
          Hedef(rt.w / CW, 0, 0)
          local zemin = B.Doku("kimlik2_zemin")
          if zemin then
               surface.SetMaterial(zemin)
               surface.SetDrawColor(255, 255, 255, 255)
               surface.DrawTexturedRect(0, 0, rt.w, rt.h)
               draw.NoTexture()
          else
               Rellenar({{0, 0}, {152, 0}, {141.4, CH}, {0, CH}}, T.serit2)
          end
          ZeminCizgileri(arka)
          Filigran()
          if arka then ArkaYazilar(kart) else OnYazilar(kart or {bos = true}) end
     end)
end

-- Son çizim: saydam hedefe yuvarlak köşeli kart + (ön yüzde) kemerli portre + folyo parıltısı
function K.SonCiz(hedef, yuz, arka, portreMat, parilti)
     render.PushRenderTarget(hedef.rt)
     render.Clear(0, 0, 0, 0, true, true)
     cam.Start2D()
     Hedef(hedef.w / CW, 0, 0)
     surface.SetMaterial(yuz.ui)
     surface.SetDrawColor(255, 255, 255, 255)
     surface.DrawPoly(PolyUV(Yuvarlak(0, 0, CW, CH, 17, 6), 0, 0, CW, CH))
     render.OverrideAlphaWriteEnable(true, false)
     if not arka and portreMat then
          surface.SetMaterial(portreMat)
          surface.SetDrawColor(255, 255, 255, 255)
          surface.DrawPoly(PolyUV(Kemer(POR.x, POR.y, POR.w, POR.h, 0, 14), POR.x, POR.y, POR.w, POR.h))
     end
     draw.NoTexture()
     if parilti and parilti > 0.01 then Yaz("M", "g", 142, 578, 208, T.parilti, 2, 0, parilti) end
     render.OverrideAlphaWriteEnable(false)
     cam.End2D()
     render.PopRenderTarget()
end

----------------------------------------------------------------------------------------
-- Portre modeli
----------------------------------------------------------------------------------------
local function IdleSekans(ent)
     for _, f in ipairs({
          function() return ent:SelectWeightedSequence(ACT_HL2MP_IDLE) end,
          function() return ent:LookupSequence("Idle_Casual") end,
          function() return ent:SelectWeightedSequence(ACT_IDLE) end,
          function() return ent:LookupSequence("idle_all_01") end,
     }) do
          local q = f()
          if q and q >= 0 then return q end
     end
     return 0
end
K.IdleSekans = IdleSekans

function K.PortreGiydir(ent, g)
     ent:SetSkin(tonumber(g.skin) or 0)
     if istable(g.bg) then
          for i, v in ipairs(g.bg) do ent:SetBodygroup(i - 1, tonumber(v) or 0) end
     end
     if istable(g.ogr) and SardonOgrenci and SardonOgrenci.KayitGiydir then
          SardonOgrenci.KayitGiydir(ent, g.ogr)
     else
          ent.sogElle = true
     end
end

function K.PortreKamera(ent)
     ent:SetupBones()
     local b = ent:LookupBone("ValveBiped.Bip01_Head1")
     local bas = b and ent:GetBonePosition(b)
     if not bas or bas:IsZero() then bas = Vector(0, 0, 64) end
     return bas + Vector(40, -7, 1), bas + Vector(0, 0, -3), 30
end

function K.ModelGecerli(g)
     return istable(g) and isstring(g.model) and g.model ~= "" and util.IsValidModel(g.model)
end

-- Çizim bağlamı dışında hazırlanan portre modeli (kemik/sekans Think'te; çizimde SetCycle kemiğe yansımıyor)
function K.PortreModel(g)
     if not K.ModelGecerli(g) then return nil end
     local ent = ClientsideModel(g.model, RENDERGROUP_OPAQUE)
     if not IsValid(ent) then return nil end
     ent:SetNoDraw(true)
     ent:SetPos(vector_origin)
     ent:SetAngles(angle_zero)
     K.PortreGiydir(ent, g)
     local q = IdleSekans(ent)
     ent:ResetSequence(q)
     ent:SetSequence(q)
     ent:SetCycle(math.Rand(0, 1))
     ent:InvalidateBoneCache()
     ent:SetupBones()
     ent.kimlikKam, ent.kimlikBak, ent.kimlikFov = K.PortreKamera(ent)
     return ent
end

function K.PortreEliminar(ent)
     if not IsValid(ent) then return end
     if SardonOgrenci and SardonOgrenci.OnizlemeTemizle then pcall(SardonOgrenci.OnizlemeTemizle, ent) end
     ent:Remove()
end

-- Portreyi RT'ye çiz (PostRender içinde). sallanma: kadraj ve bakış gezinmesi için zaman
function K.PortreCiz(ent, sallanma)
     local pr = RTYap("sb_kimlik2_portre", 256, 326, true)
     local kam, bak = ent.kimlikKam, ent.kimlikBak
     if sallanma then
          kam = kam + Vector(0, math.sin(sallanma * 0.37) * 1.4, math.sin(sallanma * 0.53) * 0.8)
          bak = bak + Vector(0, math.sin(sallanma * 0.29) * 0.6, 0)
     end
     render.PushRenderTarget(pr.rt)
     render.Clear(T.portre.r, T.portre.g, T.portre.b, 255, true, true)
     cam.Start3D(kam, (bak - kam):Angle(), ent.kimlikFov or 30, 0, 0, pr.w, pr.h)
          render.SuppressEngineLighting(true)
          render.SetLightingOrigin(bak)
          render.ResetModelLighting(0.32, 0.29, 0.24)
          render.SetModelLighting(BOX_FRONT, 1, 0.93, 0.82)
          render.SetModelLighting(BOX_TOP, 0.62, 0.56, 0.46)
          render.SetModelLighting(BOX_RIGHT, 0.42, 0.38, 0.32)
          render.SetColorModulation(1, 0.96, 0.9)
          render.SetBlend(1)
          local ok, hata = pcall(function()
               ent:DrawModel()
               if ent.sogS and SardonOgrenci and SardonOgrenci.ParcaCiz then SardonOgrenci.ParcaCiz(ent) end
          end)
          render.SetColorModulation(1, 1, 1)
          render.SuppressEngineLighting(false)
     cam.End3D()
     render.PopRenderTarget()
     if not ok then error(hata, 0) end
     return pr
end

-- Tek seferlik tam pişirme (dünyadaki kart, defter sayfası): PostRender işi içinde çağrılır.
-- ent: K.PortreModel ile atrásden hazırlanmış model (nil olabilir; işten sonra silinir)
function K.TamPisir(hedef, kart, arka, ent)
     local gecici = RTYap("sb_kimlik2_gecici", 1200, 700)
     K.YuzPisir(gecici, kart, arka)
     local portre
     if not arka and IsValid(ent) then
          local ok = pcall(function() portre = K.PortreCiz(ent) end)
          if not ok then portre = nil end
     end
     K.SonCiz(hedef, gecici, arka, portre and portre.dunya, 0)
     K.PortreEliminar(ent)
end

----------------------------------------------------------------------------------------
-- Mostrarilen kartlar (L menüsünde K17: kimliğini gösteren persona)
----------------------------------------------------------------------------------------
K.Gorulen = K.Gorulen or {} -- [oyuncu] = {no, ad, an}

function K.GorulenBilgi(hedef)
     local g = K.Gorulen[hedef]
     if g and CurTime() - g.an <= A.GorduSure then return g end
end

-- Funcionario kartı gösterilen personanin dosyasını ister; sunucu kartın kaydını çözer (sahteyse uyarır)
local sicilBekleyen = {}
function K.ExpedienteIste(hedef, fn)
     sicilBekleyen[hedef:EntIndex()] = fn
     B.Iste("kimlik.sicil", {ent = hedef:EntIndex()})
end

----------------------------------------------------------------------------------------
-- Tuşlar: Tuş Atamaları › "[Kimlik] Kartı çevir" ([sardon] config sh_init kimlik_cevir), Esc kapatır
----------------------------------------------------------------------------------------
function K.Tus()
     local ok, t = pcall(function() return SardonConfig:Get("kimlik_cevir") end)
     return (ok and tonumber(t)) or KEY_K
end

function K.TusAdi()
     return input.GetKeyName(K.Tus()) or "K"
end

-- [K] gibi küçük tuş kutusu; dönüş: genişlik (tasarım px)
function K.TusKutusu(metin, x, y)
     local w = math.max(30, U.Olc(metin, 13, 600, 1) + 16)
     U.Kutu(x, y - 14, w, 28, R.zeminKoyu, 0.9)
     U.Cerceve(x, y - 14, w, 28, R.altinAcik, 0.85)
     U.Yazi(metin, 13, 600, x + w / 2, y, R.altinAcik, 1, 1)
     return w
end

B.Kanca("PlayerButtonDown", "SardonBakanlik.KimlikTus", function(ply, tus)
     if ply ~= LocalPlayer() or not IsFirstTimePredicted() then return end
     local p = K.Panel
     if not IsValid(p) or p.kapaniyor or tus ~= K.Tus() then return end
     if vgui.GetKeyboardFocus() then return end
     local e = p:Secili()
     if e and not e.bos then p:Cevir() end
end)

----------------------------------------------------------------------------------------
-- Mostrarim paneli (kompakt kart). Kart son RT'den çizilir; çevirmede perspektifli dikey şeritler.
-- Mühür (çevir) ve köşe halkası (kapat) kart dönerken yerinde kalır.
----------------------------------------------------------------------------------------
local DURUM_RENK = {gecerli = Hex("3f7a4c"), kayip = Hex("9b2f26"), sahte = Hex("9b2f26"), iptal = Hex("a07a2c"), vefat = Hex("6d5a8c"), bekliyor = Hex("3f7a4c")}
local ROL_AD = {bakanlik = "Consulta del Ministerio", satcher = "Información de raptador", profesor = "Registro escolar"}
local PAD_L, PAD_T, PAD_R, PAD_B = 20, 22, 20, 25
local YAN_W, YAN_ARA = 330, 18
local CEVIR_SURE = 0.65
local GRAD_U = Material("vgui/gradient-u")
local SERIT_SAY = 24

-- cubic-bezier(.26,.68,.22,1)
local function Bezier(t)
     local x1, y1, x2, y2 = 0.26, 0.68, 0.22, 1
     local function bx(s) return 3 * (1 - s) ^ 2 * s * x1 + 3 * (1 - s) * s * s * x2 + s ^ 3 end
     local function by(s) return 3 * (1 - s) ^ 2 * s * y1 + 3 * (1 - s) * s * s * y2 + s ^ 3 end
     local lo, hi = 0, 1
     for _ = 1, 18 do
          local mid = (lo + hi) / 2
          if bx(mid) < t then lo = mid else hi = mid end
     end
     return by((lo + hi) / 2)
end

local PANEL = {}

function PANEL:Init()
     self.s = math.max(0.75, ScrH() / 1080)
     self.acilis = RealTime()
     self.secili = 1
     self.yuz = "on"
     self.folyo = 0.3
     self:SetMouseInputEnabled(true)
     self:SetKeyboardInputEnabled(false)
end

function PANEL:Kur(v)
     self.kartlar = v.kartlar
     self.rol = v.rol
     self.kip = v.kip
     self.gosteren = v.gosteren and Entity(v.gosteren) or nil
     self.sure = v.kip == "kendi" and 60 or ((v.rol or #v.kartlar > 1) and 45 or 14)
     self.otomatik = v.kip ~= "kendi"
     self.tw = PAD_L + CW + PAD_R + (v.rol and (YAN_W + YAN_ARA) or 0)
     self.th = PAD_T + CH + PAD_B + (#v.kartlar > 1 and 44 or 0)
     local s = self.s
     self:SetSize(math.ceil(self.tw * s), math.ceil(self.th * s))
     local y = v.kip == "kendi" and (ScrH() - self.th * s) / 2 or (ScrH() * 0.6 - self.th * s / 2)
     self:SetPos(math.floor((ScrW() - self.tw * s) / 2), math.floor(math.Clamp(y, 10, ScrH() - self.th * s - 10)))

     self.imlecAcik = (v.rol ~= nil) or v.kip == "kendi" or #v.kartlar > 1
     if self.imlecAcik then
          self:MakePopup()
          self:SetKeyboardInputEnabled(false)
     end
     self:KartHazirla()
     local panel = self
     hook.Add("PostRender", "SardonBakanlik.KimlikPanel", function()
          if not IsValid(panel) then return hook.Remove("PostRender", "SardonBakanlik.KimlikPanel") end
          local ok, hata = pcall(panel.RTGuncelle, panel)
          if not ok and not panel.rtHata then
               panel.rtHata = true
               ErrorNoHalt("[Sardon Ministerio] kimlik kartı RT: " .. tostring(hata) .. "\n")
          end
     end)
end

function PANEL:Secili() return self.kartlar[self.secili] end

-- Seçili kartın iki yüzünü pişir, portre modelini hazırla
function PANEL:KartHazirla()
     K.PortreEliminar(self.ent)
     self.ent = nil
     self.hazir = false
     self.sonHazir = {}
     self.portreHata = nil
     local e = self:Secili()
     if not e then return end
     local kart = e.bos and {bos = true} or e.kart
     if not e.bos and e.kart then self.ent = K.PortreModel(e.kart.gorunum) end
     local panel, no = self, self.secili
     K.IsEkle(function()
          if not IsValid(panel) or panel.secili ~= no then return end
          K.YuzPisir(RTYap("sb_kimlik2_yuz_on", 1200, 700), kart, false)
          K.YuzPisir(RTYap("sb_kimlik2_yuz_arka", 1200, 700), not e.bos and kart or nil, true)
          panel.hazir = true
     end)
end

-- Her kare (PostRender): görünen yüz(ler)in son çizimi, ön yüzde canlı portre
function PANEL:RTGuncelle()
     if not self.hazir or self.kapandi then return end
     local cevir = self.cevir ~= nil
     local onGerek = self.yuz == "on" or cevir
     local arkaGerek = self.yuz == "arka" or cevir
     if onGerek then
          local portre
          if IsValid(self.ent) and not self.portreHata then
               local ok, sonuc = pcall(K.PortreCiz, self.ent, RealTime())
               if ok then portre = sonuc else
                    self.portreHata = true
                    ErrorNoHalt("[Sardon Ministerio] kimlik portresi: " .. tostring(sonuc) .. "\n")
               end
          end
          K.SonCiz(RTYap("sb_kimlik2_son_on", 1200, 700), RTYap("sb_kimlik2_yuz_on", 1200, 700), false, portre and portre.dunya, self.folyo)
          self.sonHazir.on = true
     end
     if arkaGerek then
          K.SonCiz(RTYap("sb_kimlik2_son_arka", 1200, 700), RTYap("sb_kimlik2_yuz_arka", 1200, 700), true, nil, self.folyo)
          self.sonHazir.arka = true
     end
end

function PANEL:Think()
     local gecen = RealTime() - self.acilis
     if gecen > self.sure then return self:Cerrar() end
     if IsValid(self.gosteren) and self.kip ~= "kendi" and self.gosteren:GetPos():DistToSqr(LocalPlayer():GetPos()) > 520 * 520 then return self:Cerrar() end

     if self.cevir and RealTime() - self.cevir.an >= CEVIR_SURE then
          self.yuz = self.cevir.hedef
          self.cevir = nil
     end

     -- portre: büyücü fotoğrafı gibi kıpırdar (kemikler çizim dışında)
     local ent = self.ent
     if IsValid(ent) then
          ent:FrameAdvance(FrameTime() * 0.6)
          local t = RealTime() + self.secili
          ent:SetEyeTarget(ent.kimlikKam + Vector(0, math.sin(t * 0.63) * 9, math.sin(t * 0.41) * 4))
     end

     -- folyo: imlecin yatay konumuna tepki (imleçsizde yavaş gezinir; sakin kipte sabit)
     local hedef = 0.3
     if not U.Sakin() then
          if self.imlecAcik and self:IsHovered() then
               local mx = self:CursorPos()
               hedef = math.Clamp((mx / self.s - PAD_L) / CW, 0, 1)
          else
               hedef = 0.45 + 0.35 * math.sin(RealTime() * 0.35)
          end
     end
     self.folyoX = Lerp(math.min(1, FrameTime() * 6), self.folyoX or hedef, hedef)
     -- filigranın üstünden geçerken parlar (filigran kartın ~%82'sinde)
     self.folyo = 0.05 + 0.3 * math.max(0, 1 - math.abs(self.folyoX - 0.82) / 0.35)
end

function PANEL:OnMousePressed(kod)
     local x, y = self:CursorPos()
     self.tik = {x = x, y = y, kod = kod}
end

function PANEL:Cevir()
     if self.cevir then return end
     local hedef = self.yuz == "on" and "arka" or "on"
     if U.Sakin() then
          self.yuz = hedef
     else
          self.cevir = {an = RealTime(), kaynak = self.yuz, hedef = hedef}
     end
     U.Ses("kagit")
end

function PANEL:Cerrar()
     if self.kapaniyor then return end
     self.kapaniyor = true
     self:SetMouseInputEnabled(false)
     self:AlphaTo(0, 0.16, 0, function() if IsValid(self) then self:Remove() end end)
end

function PANEL:OnRemove()
     self.kapandi = true
     K.PortreEliminar(self.ent)
     hook.Remove("PostRender", "SardonBakanlik.KimlikPanel")
     if K.Panel == self then K.Panel = nil end
end

function PANEL:Sec(i)
     i = math.Clamp(i, 1, #self.kartlar)
     if i == self.secili then return end
     self.secili = i
     self.yuz = "on"
     self.cevir = nil
     self:KartHazirla()
     U.Ses("kagit")
end

function PANEL:Cikar()
     table.remove(self.kartlar, self.secili)
     if #self.kartlar == 0 then return self:Cerrar() end
     self.secili = math.min(self.secili, #self.kartlar)
     self:KartHazirla()
end

function PANEL:Paint(w, h)
     local u = Sakla()
     local ok, hata = pcall(self.Ciz, self, w, h)
     surface.SetAlphaMultiplier(1)
     GeriKoy(u)
     if not ok and not self.hataBasildi then
          self.hataBasildi = true
          ErrorNoHalt("[Sardon Ministerio] kimlik kartı çizimi: " .. tostring(hata) .. "\n")
     end
end

-- Kart gölgesi: 0 12px 30px #0004
local function Golge(kx, ky, olcek, alfa)
     for i = 1, 7 do
          local g = i * 4
          Rellenar(Yuvarlak(kx + CW / 2 - (CW / 2 + g) * olcek, ky + 12 - g * 0.6, (CW + 2 * g) * olcek, CH + 2 * g * 0.6, 17 + g, 4), T.siyah, 0.045 * alfa)
     end
end

function PANEL:KartCiz(kx, ky, alfa)
     local s = self.s
     local x0, y0, kw, kh = kx * s, ky * s, CW * s, CH * s
     local gerek = self.cevir and (self.sonHazir.on and self.sonHazir.arka) or self.sonHazir[self.yuz]
     if not self.hazir or not gerek then
          Rellenar(Yuvarlak(kx, ky, CW, CH, 17, 6), T.kagit, alfa)
          Rellenar({{kx, ky + 17}, {kx + 152, ky + 17}, {kx + 141.4, ky + CH - 17}, {kx, ky + CH - 17}}, T.serit2, alfa)
          return
     end
     local son = RTYap(self.yuz == "on" and "sb_kimlik2_son_on" or "sb_kimlik2_son_arka", 1200, 700)
     if not self.cevir then
          Golge(kx, ky, 1, alfa)
          surface.SetMaterial(son.ui)
          surface.SetDrawColor(255, 255, 255, 255 * alfa)
          surface.DrawTexturedRect(x0, y0, kw, kh)
          draw.NoTexture()
          return
     end
     -- perspektifli çevirme (CSS perspective 1400px, rotateY 0 → 180)
     local t = math.Clamp((RealTime() - self.cevir.an) / CEVIR_SURE, 0, 1)
     local aci = math.pi * Bezier(t)
     local yuz = self.cevir.kaynak
     if aci > math.pi / 2 then
          yuz = self.cevir.hedef
          aci = aci - math.pi
     end
     Golge(kx, ky, math.abs(math.cos(aci)), alfa)
     son = RTYap(yuz == "on" and "sb_kimlik2_son_on" or "sb_kimlik2_son_arka", 1200, 700)
     local cx, cy = x0 + kw / 2, y0 + kh / 2
     local P = 1400 * s
     local c, s = math.cos(aci), math.sin(aci)
     local function Nokta(x, y, u, v)
          local z = x * s
          local f = P / (P - z)
          return {x = cx + x * c * f, y = cy + y * f, u = u, v = v}
     end
     surface.SetMaterial(son.ui)
     surface.SetDrawColor(255, 255, 255, 255 * alfa)
     for i = 0, SERIT_SAY - 1 do
          local u0, u1 = i / SERIT_SAY, (i + 1) / SERIT_SAY
          local xa, xb = (u0 - 0.5) * kw, (u1 - 0.5) * kw
          local p = {Nokta(xa, -kh / 2, u0, 0), Nokta(xb, -kh / 2, u1, 0), Nokta(xb, kh / 2, u1, 1), Nokta(xa, kh / 2, u0, 1)}
          if c < 0 then p = {p[2], p[1], p[4], p[3]} end
          surface.DrawPoly(p)
     end
     draw.NoTexture()
end

function PANEL:Ciz(w, h)
     local s = self.s
     U.panel = self
     U.S, U.OX, U.OY = s, 0, 0
     U.fareX, U.fareY = self:CursorPos()
     U.tik, self.tik = self.tik, nil
     U.teker, U.engel, U.klip, U.imlec, U.ipucu = 0, false, nil, false, nil

     local gecen = RealTime() - self.acilis
     local alfa = U.Kolay(gecen / 0.22)
     local kx, ky = PAD_L, PAD_T + (1 - alfa) * 10
     Hedef(s, 0, 0)

     self:KartCiz(kx, ky, alfa)

     -- sabit kontroller (kart dönerken yerinde)
     surface.SetAlphaMultiplier(alfa)
     local e = self:Secili()
     Hedef(s, kx * s, ky * s)
     if e and not e.bos then
          local ust = self.imlecAcik and U.Icinde(kx + 15, ky + 262, 120, 80)
          local muhur = B.Doku("kimlik2_muhur")
          local boy = 46 * (ust and 1.06 or 1)
          if muhur then
               surface.SetMaterial(muhur)
               surface.SetDrawColor(255, 255, 255, 255)
               surface.DrawTexturedRectRotated(PX(75), PY(290), boy * s, boy * s, ust and 9 or 0)
               draw.NoTexture()
          else
               Daire(75, 290, 22, T.kizil)
          end
          local hedefYuz = (self.cevir and self.cevir.hedef or self.yuz) == "on" and "Reverso" or "Anverso"
          local tus = B.Buyuk(K.TusAdi())
          local w1, w2 = Olc(hedefYuz, "g", 15, 0.15), Olc(tus, "a", 12, 0.3)
          local lx = 75 - (w1 + 8 + w2) / 2
          Yaz(hedefYuz, "g", 15, lx, 326, T.muhurYazi, 0, 0.15)
          Yaz(tus, "a", 12, lx + w1 + 8, 327, T.tus, 0, 0.3)
          if ust then
               U.imlec = true
               if U.Tik(kx + 15, ky + 262, 120, 80) then self:Cevir() end
          end

          -- yüz göstergesi
          local arkaMi = (self.cevir and self.cevir.hedef or self.yuz) == "arka"
          Daire(524, 330, 2.2, arkaMi and T.noktaSoluk or T.nokta)
          Daire(533, 330, 2.2, arkaMi and T.nokta or T.noktaSoluk)
          Yaz(arkaMi and "Reverso" or "Anverso", "a", 12, 541, 330, T.ilerleme, 0, 0.3)
     end

     -- köşe halkası: kapat (otomatik kapanan kipte kalan süre halkada)
     local hc = self.imlecAcik and U.Icinde(kx + 579, ky - 12, 32, 32)
     Daire(595, 4, 15, hc and T.halkaUstu or T.halkaZemin)
     Cember(595, 4, 15, T.halka, 1)
     if self.otomatik then
          local kalan = math.Clamp(1 - gecen / self.sure, 0, 1)
          Cember(595, 4, 17.5, Hex("e6ba62"), 0.9, -math.pi / 2, -math.pi / 2 + kalan * 2 * math.pi, 3)
     end
     local d = 4.6
     surface.SetDrawColor(T.carpi.r, T.carpi.g, T.carpi.b, 255)
     for o = -0.6, 0.6, 0.6 do
          surface.DrawLine(PX(595 - d + o), PY(4 - d), PX(595 + d + o), PY(4 + d))
          surface.DrawLine(PX(595 + d + o), PY(4 - d), PX(595 - d + o), PY(4 + d))
     end
     if hc then
          U.imlec = true
          if U.Tik(kx + 579, ky - 12, 32, 32) then self:Cerrar() end
     end

     -- Varios documentos (persona esposada)
     if #self.kartlar > 1 then
          local by = CH + 18
          local onceki = U.Icinde(kx, ky + by, 40, 32)
          local sonraki = U.Icinde(kx + 150, ky + by, 40, 32)
          for i, x in ipairs({0, 150}) do
               local ust2 = (i == 1 and onceki) or (i == 2 and sonraki)
               Rellenar(Yuvarlak(x, by, 40, 32, 16, 4), ust2 and T.halkaUstu or T.halkaZemin, 0.95)
               Yaz(i == 1 and "‹" or "›", "g", 20, x + 20, by + 15, T.carpi, 1)
          end
          Yaz(self.secili .. " / " .. #self.kartlar, "g", 16, 95, by + 16, T.muhurYazi, 1)
          Yaz("Documentos tomados a la persona restringida", "a", 13, 210, by + 16, T.panelSoluk, 0, 0.2)
          if onceki then U.imlec = true if U.Tik(kx, ky + by, 40, 32) then self:Sec(self.secili - 1) end end
          if sonraki then U.imlec = true if U.Tik(kx + 150, ky + by, 40, 32) then self:Sec(self.secili + 1) end end
     end

     if self.rol then
          Hedef(s, (kx + CW + PAD_R + YAN_ARA - 20) * s, ky * s)
          self:SorguCiz(kx + CW + PAD_R + YAN_ARA - 20, ky)
     end
     surface.SetAlphaMultiplier(1)
     self:SetCursor(U.imlec and "hand" or "arrow")
end

-- Sorgu kartı düğmesi (Hedef: sorgu kartının sol üstü; ux, uy: U koordinatı için kartın panel ofseti)
local function Dugme2(ux, uy, x, y, w, h, metin, tehlike, kapali)
     local ust = not kapali and U.Icinde(ux + x, uy + y, w, h)
     local zemin = tehlike and Hex("5a1e19") or T.halkaZemin
     Rellenar(Yuvarlak(x, y, w, h, h / 2, 4), ust and (tehlike and Hex("7a2a22") or T.halkaUstu) or zemin, kapali and 0.45 or 1)
     surface.SetDrawColor(T.halka.r, T.halka.g, T.halka.b, kapali and 70 or 200)
     local p = Yuvarlak(x, y, w, h, h / 2, 4)
     for i = 1, #p do
          local a, b = p[i], p[i % #p + 1]
          surface.DrawLine(PX(a[1]), PY(a[2]), PX(b[1]), PY(b[2]))
     end
     Yaz(B.Buyuk(metin), "ab", 11, x + w / 2, y + h / 2, kapali and T.panelSoluk or T.carpi, 1, 1.1, kapali and 0.6 or 1)
     if ust then
          U.imlec = true
          if U.Tik(ux + x, uy + y, w, h) then
               U.Ses("tik")
               return true
          end
     end
     return false
end

function PANEL:SorguCiz(ux, uy)
     local w, h = YAN_W, CH
     local zemin = Yuvarlak(0, 0, w, h, 17, 6)
     Rellenar(zemin, T.serit2, 0.97)
     surface.SetMaterial(GRAD_U)
     surface.SetDrawColor(T.serit1.r, T.serit1.g, T.serit1.b, 150)
     surface.DrawTexturedRect(PX(8), PY(6), (w - 16) * Z.k, h * 0.5 * Z.k)
     draw.NoTexture()
     surface.SetDrawColor(T.halka.r, T.halka.g, T.halka.b, 150)
     for i = 1, #zemin do
          local a, b = zemin[i], zemin[i % #zemin + 1]
          surface.DrawLine(PX(a[1]), PY(a[2]), PX(b[1]), PY(b[2]))
     end
     Yaz(ROL_AD[self.rol] or "Sorgu", "g", 18, 22, 28, T.muhurYazi)
     local e = self:Secili()
     local alt = self.kip == "zorla" and "Desde la persona restringida" or (GorunenAd(self.gosteren) .. " extendió su identidad")
     Yaz(Kisalt(alt, "a", 12, w - 44), "a", 12, 22, 50, T.panelSoluk, 0, 0.2)
     Kutu(22, 64, w - 44, 1 / Z.k, T.halka, 0.4)

     local x0, iw = 22, w - 44
     local cy = 84
     local function Satir(metin, renk, aile, boy)
          for _, s in ipairs(Sar(metin, aile or "a", boy or 14, iw)) do
               Yaz(s, aile or "a", boy or 14, x0, cy, renk or T.panelYazi, 0, 0.15)
               cy = cy + 20
          end
          cy = cy + 4
     end

     if e.bos then
          Satir("Documento sin rellenar ni sellar. El Ministerio no emite documentos así.", T.panelYazi)
          if self.rol == "bakanlik" and Dugme2(ux, uy, x0, h - 54, iw, 36, "El koy", true) then
               B.Iste("kimlik.elkoy", {token = e.token})
               self:Cikar()
          end
          return
     end

     local q = e.sorgu
     if not q then
          Satir(self.rol == "bakanlik" and "Consulta el número en el registro del Ministerio con tinta Protean: validez, busca, deudas y licencias." or
               (self.rol == "snatcher" and "Que el agente busque el número en los registros: ¿registrado? ¿recompensa?" or
               "Consulta el registro escolar: ¿es estudiante, casa y curso?"), T.panelYazi)
          if Dugme2(ux, uy, x0, h - 54, iw, 36, self.rol == "bakanlik" and "Consultar expediente" or "Kayda bak") then
               e.sorgu = {an = RealTime()}
               B.Iste("kimlik.sorgu", {token = e.token})
          end
          return
     end

     local t = RealTime() - q.an
     if not q.sonuc or t < 1.6 then
          local k = (t % 1.6) / 1.6
          Yaz("La tinta consulta el registro…", "g", 15, x0, cy + 4, T.panelYazi)
          Kutu(x0, cy + 22, iw, 1 / Z.k, T.halka, 0.35)
          Kutu(x0, cy + 22, iw * k, 1.5 / Z.k, Hex("e6ba62"), 1)
          for i = 0, 2 do
               Baklava(x0 + 6 + i * 16, cy + 44, 4, T.halka, 0.3 + 0.7 * math.max(0, math.sin(RealTime() * 4 - i * 0.9)))
          end
          return
     end

     local r = q.sonuc
     local renk = DURUM_RENK[r.durum] or T.halka
     local nabiz = (r.durum == "sahte" or r.durum == "kayip") and (0.7 + 0.3 * math.sin(RealTime() * 5)) or 1
     Rellenar(Yuvarlak(x0, cy - 4, iw, 34, 8, 3), renk, 0.85 * nabiz)
     Yaz(B.Buyuk(K.DurumAd[r.durum] or r.durum), "ab", 12, x0 + iw / 2, cy + 13, T.carpi, 1, 1)
     cy = cy + 44

     if r.durum == "sahte" then Satir("Este número no figura en el registro del Ministerio." .. (self.rol == "bakanlik" and " (KR-6)" or ""), Hex("e59a8f")) end
     if r.durum == "kayip" then Satir("El titular ha denunciado la pérdida." .. (self.rol == "bakanlik" and " (KR-7)" or ""), Hex("e59a8f")) end
     if r.durum == "iptal" then Satir("Se ha emitido un documento nuevo en su lugar.", Hex("e6ba62")) end
     if r.durum == "vefat" then Satir("El titular figura como fallecido en el registro del Ministerio.", Hex("b9a6d9")) end

     if r.aranan then
          Satir("SE BUSCA" .. ((r.odul or 0) > 0 and (" · recompensa " .. B.Para(r.odul)) or ""), Hex("e59a8f"), "ab", 13)
     elseif r.durum ~= "sahte" and (self.rol == "bakanlik" or self.rol == "snatcher") then
          Satir("No hay registro de búsqueda.", T.panelSoluk)
     end

     if self.rol == "bakanlik" and r.durum ~= "sahte" then
          Satir((r.borc or 0) > 0 and ("Multa impagada: " .. B.Para(r.borc)) or "Sin deuda con el Ministerio.", (r.borc or 0) > 0 and Hex("e6ba62") or T.panelSoluk)
          if (r.men or 0) > 0 then Satir("Prohibición de varita: " .. B.SureUzun(r.men), Hex("b9a6d9")) end
          if istable(r.ruhsatlar) and #r.ruhsatlar > 0 then Satir("Ruhsat: " .. table.concat(r.ruhsatlar, ", "), T.panelYazi) end
          if istable(r.bayraklar) and #r.bayraklar > 0 then
               local adlar = {}
               for _, b in ipairs(r.bayraklar) do
                    local ad = b
                    for _, t2 in ipairs(B.Bayraklar or {}) do if t2.id == b then ad = t2.ad end end
                    adlar[#adlar + 1] = ad
               end
               Satir("Expediente: " .. table.concat(adlar, ", "), Hex("e59a8f"))
          end
     elseif self.rol == "profesor" and r.durum ~= "sahte" then
          local hane = K.Casaler[r.hane or 0]
          Satir("Registro escolar: " .. (hane and (hane .. ((r.yil or 0) > 0 and (" · " .. r.yil .. ".º curso") or "")) or "no es estudiante"), T.panelYazi)
          if e.kart and ((r.hane or 0) ~= (e.kart.hane or 0) or ((r.yil or 0) > 0 and (r.yil or 0) ~= (e.kart.yil or 0))) then
               Satir("No coincide con lo impreso en la tarjeta.", Hex("e59a8f"))
          end
     end

     if self.rol == "bakanlik" then
          local bw = (iw - 12) / 3
          local by = h - 52
          local gosteren = self.gosteren
          if Dugme2(ux, uy, x0, by, bw, 34, "Expediente", false, not r.charid) then
               local id = r.charid
               self:Cerrar()
               timer.Simple(0, function() B.Ac("sicil", {kisi = id}) end)
          end
          if Dugme2(ux, uy, x0 + bw + 6, by, bw, 34, "Ceza", false, not IsValid(gosteren) or not B.Yetkili(LocalPlayer(), "ceza")) then
               local id, ad, idx = r.charid, e.kart and e.kart.ad or "Persona", gosteren:EntIndex()
               self:Cerrar()
               timer.Simple(0, function()
                    B.Ac("sicil", id and {kisi = id} or nil)
                    B.KanunSec("Multa · " .. ad, function(kod) B.Iste("ceza.kes", {ent = idx, kod = kod}) end, true)
               end)
          end
          if Dugme2(ux, uy, x0 + (bw + 6) * 2, by, bw, 34, "El koy", true, self.kip == "kendi") then
               B.Iste("kimlik.elkoy", {token = e.token})
               self:Cikar()
          end
     end
end

vgui.Register("SardonBakanlik.KimlikKart", PANEL, "EditablePanel")

function K.KartAc(v)
     if IsValid(K.Panel) then K.Panel:Remove() end
     local p = vgui.Create("SardonBakanlik.KimlikKart")
     K.Panel = p
     p:Kur(v)
     U.Ses("kagit")
     return p
end

B.Kanca("OnPauseMenuShow", "SardonBakanlik.KimlikKart", function()
     if IsValid(K.Panel) and not K.Panel.kapaniyor then
          K.Panel:Cerrar()
          return false
     end
     if IsValid(K.Istem) then
          K.Istem:Yanit(nil)
          return false
     end
end)

----------------------------------------------------------------------------------------
-- Küçük açılır pencereler için ortak temel (istem, nüfus, sahte)
----------------------------------------------------------------------------------------
local KUCUK = {}

function KUCUK:Init()
     self.s = math.max(0.66, ScrH() / 1080)
     self.acilis = RealTime()
end

function KUCUK:Boyut(tw, th, alt)
     self.tw, self.th = tw, th
     local s = self.s
     self:SetSize(math.ceil(tw * s), math.ceil(th * s))
     if alt then
          self:SetPos(math.floor((ScrW() - tw * s) / 2), math.floor(ScrH() - th * s - alt * s))
     else
          self:Center()
     end
end

function KUCUK:OnMousePressed(kod)
     local x, y = self:CursorPos()
     self.tik = {x = x, y = y, kod = kod}
end

function KUCUK:Paint(w, h)
     local u = Sakla()
     U.panel = self
     U.S, U.OX, U.OY = self.s, 0, 0
     U.fareX, U.fareY = self:CursorPos()
     U.tik, self.tik = self.tik, nil
     U.teker, U.engel, U.klip, U.imlec, U.ipucu = 0, false, nil, false, nil
     surface.SetAlphaMultiplier(math.min(1, (RealTime() - self.acilis) / 0.18))
     local tw, th = self.tw, self.th
     U.Kutu(0, 0, tw, th, R.zemin, 0.97)
     U.Gecis(0, 0, tw, 70, R.panelAcik, 0.9, "u")
     U.Cerceve(0, 0, tw, th, R.altin, 0.9)
     U.Cerceve(4, 4, tw - 8, th - 8, R.cizgi, 0.5)
     U.Baklava(0, 0, 4, R.altinAcik, 1) U.Baklava(tw, 0, 4, R.altinAcik, 1)
     U.Baklava(0, th, 4, R.altinAcik, 1) U.Baklava(tw, th, 4, R.altinAcik, 1)
     local ok, hata = pcall(self.Icerik, self, tw, th)
     surface.SetAlphaMultiplier(1)
     self:SetCursor(U.imlec and "hand" or "arrow")
     GeriKoy(u)
     if not ok and not self.hataBasildi then
          self.hataBasildi = true
          ErrorNoHalt("[Sardon Ministerio] kimlik penceresi: " .. tostring(hata) .. "\n")
     end
end

function KUCUK:Icerik() end

vgui.Register("SardonBakanlik.KimlikKucuk", KUCUK, "EditablePanel")

----------------------------------------------------------------------------------------
-- Solicitud de identidad
----------------------------------------------------------------------------------------
local ISTEM = {}
local ROL_KIM = {bakanlik = "Agente del Ministerio", satcher = "Snatcher", profesor = "Profesor"}
local ROL_RENK = {bakanlik = R.altinAcik, satcher = R.kizil, profesor = R.mavi}

function ISTEM:Kur(v)
     self.isteyen = Entity(v.isteyen or 0)
     self.rol = v.rol
     self.sure = v.sure or A.IsteSure
     self.kartlar = {}
     local char = LocalPlayer():GetCharacter()
     for _, it in ipairs(K.Kartlar(char)) do
          if not it:GetData("bos") then self.kartlar[#self.kartlar + 1] = it end
     end
     local n = math.max(1, math.min(#self.kartlar, 4))
     self:Boyut(520, 196 + n * 52, 150)
     self:MakePopup()
     self:SetKeyboardInputEnabled(false)
     U.Ses("kagit")
end

function ISTEM:Yanit(item)
     if self.cevaplandi then return end
     self.cevaplandi = true
     B.Iste("kimlik.yanit", {item = item and item.id or nil})
     self:Remove()
end

function ISTEM:Think()
     if RealTime() - self.acilis > self.sure + 0.5 then
          self.cevaplandi = true
          self:Remove()
     end
end

function ISTEM:OnRemove()
     if K.Istem == self then K.Istem = nil end
end

function ISTEM:Icerik(tw, th)
     local renk = ROL_RENK[self.rol] or R.altinAcik
     U.Yazi("Solicitud de identidad", 20, 600, 28, 32, R.fildisiAcik)
     U.Etiket(ROL_KIM[self.rol] or "Funcionario", tw - 28, 32, renk, 2, 10)
     U.SusCizgi(28, 56, tw - 56, R.altin, 0.6)
     U.Paragraf(GorunenAd(self.isteyen) .. " quiere ver tu identidad. Si aceptas, se le entrega la tarjeta.", 16, 700, 28, 70, tw - 56, R.govde, 22, 2)

     local kalan = math.Clamp(1 - (RealTime() - self.acilis) / self.sure, 0, 1)
     U.Kutu(28, 120, (tw - 56) * kalan, 2, renk, 0.9)

     local y = 136
     if #self.kartlar == 0 then
          U.Yazi("No lleva documento de identidad.", 16, 700, 28, y + 22, R.soluk)
          y = y + 52
     end
     for i, it in ipairs(self.kartlar) do
          if i > 4 then break end
          U.Kart(28, y, tw - 56, 44)
          U.Yazi(U.Kisalt(tostring(it:GetData("ad", "?")), 17, 600, tw - 240), 17, 600, 44, y + 15, R.fildisi)
          U.Yazi(tostring(it:GetData("no", "")), 16, 700, 44, y + 33, R.soluk)
          if U.Dugme(tw - 160, y + 5, 118, 34, "Mostrar", "ana") then return self:Yanit(it) end
          y = y + 52
     end
     if U.Dugme(tw - 188, th - 52, 160, 36, #self.kartlar == 0 and "No tengo identidad" or "Rechazar", #self.kartlar == 0 and "ikincil" or "tehlike") then
          return self:Yanit(nil)
     end
     if #self.kartlar > 0 then U.Yazi("Rechazar es delito contra el Ministerio.", 16, 700, 28, th - 34, R.soluk, 0, nil, self.rol == "bakanlik" and 0.9 or 0) end
end

vgui.Register("SardonBakanlik.KimlikIstem", ISTEM, "SardonBakanlik.KimlikKucuk")

-- Kan durumu seçimi 11-16'da kaldırıldı: değer [fx] irk'ten gelir (sunucu K.KisiKan)

----------------------------------------------------------------------------------------
-- Sahte belge doldurma
----------------------------------------------------------------------------------------
local SAHTE = {}

function SAHTE:Kur(itemID)
     self.item = itemID
     self.hane, self.yil, self.kan = 0, 1, nil
     self:Boyut(660, 520)
     self:MakePopup()
     U.GirdiTemizle("kimlik.sahte.")
end

function SAHTE:OnRemove()
     U.GirdiTemizle("kimlik.sahte.")
     if K.Sahte == self then K.Sahte = nil end
end

local function Secenekler(x, y, liste, secili, fn)
     local cx = x
     for _, s in ipairs(liste) do
          local w = U.Olc(s.ad, 16, 600) + 26
          local sec = s.id == secili
          local ustunde = U.Icinde(cx, y, w, 32)
          U.Kutu(cx, y, w, 32, sec and R.altin or R.zeminKoyu, sec and 0.24 or 0.7)
          U.Cerceve(cx, y, w, 32, (sec or ustunde) and R.altinAcik or R.cizgi, (sec or ustunde) and 1 or 0.7)
          U.Yazi(s.ad, 16, 600, cx + w / 2, y + 16, sec and R.fildisiAcik or R.govde, 1)
          if ustunde then
               U.imlec = true
               if U.Tik(cx, y, w, 32) then U.Ses("uzeri") fn(s.id) end
          end
          cx = cx + w + 8
     end
end

function SAHTE:Icerik(tw, th)
     U.Yazi("Documento de identidad en blanco", 20, 600, 28, 32, R.fildisiAcik)
     U.Etiket("Oficio de los Mortífagos", tw - 28, 32, R.kizil, 2, 10)
     U.SusCizgi(28, 56, tw - 56, R.altin, 0.6)
     U.Paragraf("Lo que escribas se creerá. Tu rostro queda fijado como hoy; no podrás cambiarlo. Si el Ministerio consulta el número, no existirá.", 16, 700, 28, 70, tw - 56, R.ada, 22, 3)

     local y = 150
     U.Etiket("Nombre y apellidos", 28, y, R.ust, 0, 10)
     local ad = U.Girdi("kimlik.sahte.ad", 28, y + 14, tw - 56, 38, "Belgedeki ad", {maks = 48})
     y = y + 70
     U.Etiket("Casa", 28, y, R.ust, 0, 10)
     local haneler = {{id = 0, ad = "Yok"}}
     for i, h in ipairs(K.Casaler) do haneler[#haneler + 1] = {id = i, ad = h} end
     Secenekler(28, y + 14, haneler, self.hane, function(id) self.hane = id end)
     y = y + 62
     if self.hane > 0 then
          U.Etiket("Curso", 28, y, R.ust, 0, 10)
          local yillar = {}
          for i = 1, 7 do yillar[i] = {id = i, ad = tostring(i)} end
          Secenekler(28, y + 14, yillar, self.yil, function(id) self.yil = id end)
          y = y + 62
     end
     U.Etiket("Kan durumu", 28, y, R.ust, 0, 10)
     local kanlar = {{id = "", ad = "Dejar en blanco"}}
     for _, k in ipairs(K.Kanlar) do kanlar[#kanlar + 1] = {id = k.id, ad = k.ad} end
     Secenekler(28, y + 14, kanlar, self.kan or "", function(id) self.kan = id end)
     y = y + 62
     U.Etiket("Meslek", 28, y, R.ust, 0, 10)
     local meslek = U.Girdi("kimlik.sahte.meslek", 28, y + 14, tw - 56, 38, self.hane > 0 and "Estudiante de Hogwarts" or "Mago independiente", {maks = 40})

     local yeterli = utf8.len(string.Trim(ad)) and utf8.len(string.Trim(ad)) >= 3
     if U.Dugme(tw - 228, th - 54, 200, 38, "Belgeyi doldur", "ana", not yeterli) then
          B.Iste("kimlik.doldur", {item = self.item, ad = string.Trim(ad), hane = self.hane, yil = self.yil, kan = self.kan or "", meslek = string.Trim(meslek)})
          self:Remove()
     end
     if U.Dugme(tw - 360, th - 54, 120, 38, "Cancelar", "duz") then self:Remove() end
end

vgui.Register("SardonBakanlik.KimlikSahte", SAHTE, "SardonBakanlik.KimlikKucuk")

function K.RellenarAc(itemID)
     if IsValid(K.Sahte) then K.Sahte:Remove() end
     K.Sahte = vgui.Create("SardonBakanlik.KimlikSahte")
     K.Sahte:Kur(itemID)
end

-- Defter açılınca yazı kutulu pencereler kapanır (U.Bitir onları gizler)
B.Kanca("SardonBakanlikDefter", "SardonBakanlik.KimlikPencere", function(acik)
     if not acik then return end
     if IsValid(K.Sahte) then K.Sahte:Remove() end
end)

----------------------------------------------------------------------------------------
-- Presentarucudan gelenler
----------------------------------------------------------------------------------------
local SESSIZ = {["kimlik.kart"] = true, ["kimlik.zorla"] = true, ["kimlik.sorgu"] = true, ["kimlik.ret"] = true,
     ["kimlik.istem"] = true, ["kimlik.sicilac"] = true, ["kimlik.ac"] = true}

B.Kanca("SardonBakanlikVeri", "SardonBakanlik.Kimlik", function(anahtar, v)
     if not SESSIZ[anahtar] then return end
     -- defterin "Protean mürekkebi" oynamasın: bu veriler sayfa verisi değil
     B.IstekAn[anahtar] = RealTime()

     if anahtar == "kimlik.kart" then
          local gosteren = v.gosteren and Entity(v.gosteren)
          if IsValid(gosteren) and v.kart then K.Gorulen[gosteren] = {no = v.kart.no, ad = v.kart.ad, an = CurTime()} end
          K.KartAc({kartlar = {{kart = v.kart, token = v.token}}, rol = v.rol, kip = v.kip, gosteren = v.gosteren})
     elseif anahtar == "kimlik.zorla" then
          local liste = {}
          for _, k in ipairs(v.kartlar or {}) do liste[#liste + 1] = {kart = k.kart, token = k.token, bos = k.bos} end
          if #liste > 0 then K.KartAc({kartlar = liste, rol = v.rol, kip = "zorla", gosteren = v.ent}) end
     elseif anahtar == "kimlik.sorgu" then
          local p = K.Panel
          if not IsValid(p) then return end
          for _, e in ipairs(p.kartlar or {}) do
               if e.token == v.token then
                    e.sorgu = e.sorgu or {an = RealTime() - 1.6}
                    e.sorgu.sonuc = v
                    if v.durum == "sahte" or v.durum == "kayip" then U.Ses("hata") else U.Ses("muhur") end
               end
          end
     elseif anahtar == "kimlik.ret" then
          local p = Entity(v.ent or 0)
          local ad = GorunenAd(p)
          local metin
          if v.neden == "zaman" then metin = ad .. " no respondió a la petición de identidad."
          elseif v.neden == "yok" then metin = ad .. ": no lleva documento de identidad." .. (v.kayip and " (Denunció la pérdida en ventanilla.)" or "")
          else metin = ad .. " rechazó mostrar su identidad." end
          local ply = LocalPlayer()
          if ply.Notify then ply:Notify(metin) else chat.AddText(R.altinAcik, "[Ministerio] ", color_white, metin) end
     elseif anahtar == "kimlik.istem" then
          if IsValid(K.Istem) then K.Istem:Remove() end
          K.Istem = vgui.Create("SardonBakanlik.KimlikIstem")
          K.Istem:Kur(v)
     elseif anahtar == "kimlik.ac" then
          K.SayfaAc()
     elseif anahtar == "kimlik.sicilac" then
          local fn = sicilBekleyen[v.ent or 0]
          sicilBekleyen[v.ent or 0] = nil
          if fn then fn(v.charid) end
     end
end)

concommand.Add("sardon_kimlik", function() K.SayfaAc() end)

----------------------------------------------------------------------------------------
-- Defter sayfası: Identidad y padrón (Gişe'den de açılır)
----------------------------------------------------------------------------------------
local DURUM_KISA = {gecerli = "Válido", kayip = "Perdido", iptal = "Anulado", vefat = "Fallecido", bekliyor = "Pendiente de entrega"}

local sayfa = {}

local function SayfaCiz(x, y, w, h)
     local v = B.Veri["kimlik.durum"]
     if not v then return U.Bekleniyor(x, y, w, h) end

     -- sol: kart önizleme (SHINE kompakt kart; portre pişmiş). Model çizim dışında hazırlanır (timer)
     local kx, ky = x, y + 12
     local kart = v.kart
     local kw, kh = CW, CH
     if kart then
          local anahtar = table.concat({tostring(kart.no), tostring(kart.v), tostring(kart.meslek), tostring(kart.kan), tostring(kart.yil), tostring(kart.resit), tostring(#(kart.ruhsatlar or {}))}, "#")
          if sayfa.anahtar ~= anahtar then
               sayfa.anahtar, sayfa.hazir = anahtar, false
               timer.Simple(0, function()
                    local ent = K.PortreModel(kart.gorunum)
                    K.IsEkle(function()
                         if sayfa.anahtar ~= anahtar then return K.PortreEliminar(ent) end
                         K.TamPisir(RTYap("sb_kimlik2_sayfa", 1200, 700), kart, false, ent)
                         sayfa.hazir = true
                    end)
               end)
          end
          if sayfa.hazir then
               U.Resim(RTYap("sb_kimlik2_sayfa", 1200, 700).ui, kx, ky, kw, kh)
          else
               U.Kutu(kx, ky, kw, kh, R.zeminKoyu, 0.5)
          end
     else
          U.Kutu(kx, ky, kw, kh, R.zeminKoyu, 0.7)
          U.Cerceve(kx, ky, kw, kh, R.cizgi, 0.8)
          U.Yazi(v.uygun and "No llevas un documento de identidad válido." or "El Ministerio no te emite documento de identidad.", 16, 600, kx + kw / 2, ky + kh / 2 - 12, R.fildisi, 1)
          if v.uygun then U.Yazi("Si lo perdiste, denúncialo y solicita uno nuevo.", 14, 700, kx + kw / 2, ky + kh / 2 + 14, R.soluk, 1) end
     end

     -- sol alt: belgeler
     local ly = ky + kh + 24
     U.Bolum("Documentosin", x, ly, kw)
     ly = ly + 18
     if #v.kayitlar == 0 then U.Yazi("No tienes documentos registrados.", 14, 700, x, ly + 14, R.soluk) end
     for i, r in ipairs(v.kayitlar) do
          if ly > y + h - 30 then break end
          U.Yazi(r.no, 14, 600, x + 4, ly + 14, R.fildisi, 0, 1.2)
          U.Rozet(DURUM_KISA[r.durum] or r.durum, x + 170, ly + 14, DURUM_RENK[r.durum] or R.altin, r.durum == "gecerli")
          U.Yazi(B.Tarih(r.verilis, false), 13, 700, x + 330, ly + 14, R.soluk)
          if r.elde then U.Yazi("en posesión", 13, 700, x + kw - 4, ly + 14, R.yesil, 2) end
          ly = ly + 30
     end

     -- sağ: nüfus kaydı ve işlemler
     local sx, sw = x + kw + 40, w - kw - 40
     U.Bolum("Registro civil", sx, y + 22, sw)
     local cy = y + 44
     local kan = K.KanAd[v.kan or ""]
     U.Etiket("Kan durumu", sx, cy + 10, R.ust, 0, 10)
     U.Yazi(kan or "Registro pendiente", 16, 600, sx, cy + 34, kan and R.fildisi or R.soluk)
     U.Yazi("Viene de tu familia; el Ministerio no altera el registro.", 13, 700, sx + sw, cy + 34, R.soluk, 2)
     cy = cy + 70

     U.Bolum("Trámites", sx, cy, sw)
     cy = cy + 22
     local elde = v.kart ~= nil
     local gecerliVar = false
     for _, r in ipairs(v.kayitlar) do if r.durum == "gecerli" then gecerliVar = true end end

     local function Islem(baslik, aciklama, dugme, stil, kapali, ipucu, fn)
          local hh = 44 + U.ParagrafH(aciklama, 13, 700, sw - 220, 19, 4)
          U.Kart(sx, cy, sw, hh)
          U.Yazi(baslik, 15, 600, sx + 18, cy + 22, R.fildisiAcik)
          U.Paragraf(aciklama, 13, 700, sx + 18, cy + 36, sw - 220, R.govde, 19, 4)
          if U.Dugme(sx + sw - 186, cy + hh / 2 - 19, 170, 38, dugme, stil, kapali, ipucu) then fn() end
          cy = cy + hh + 12
     end

     Islem("Denunciar pérdida o robo", "Si te han quitado el documento, denúncialo: ese número aparecerá como «perdido» al verificarlo y quien lo lleve podrá ser detenido. Sin coste.",
          "Denunciar", "tehlike", elde or not gecerliVar, elde and "Lo llevas encima." or (not gecerliVar and "No tienes un documento válido." or nil),
          function() B.Onay("Denunciar pérdida", "Tu documento válido quedará marcado como perdido. Aunque lo recuperes, no valdrá; necesitarás uno nuevo.", "Denunciar", function() B.Sor("kimlik.kayip", {}) end, true) end)

     Islem("Emitir nueva identidad", "Se anulan los documentos válidos anteriores y se imprime uno nuevo con tu aspecto actual. La tarifa va al Tesoro del Ministerio.",
          "Emitir · " .. B.Para(v.ucret or A.Ucret), "ana", elde or not v.uygun or (v.para or 0) < (v.ucret or A.Ucret),
          elde and "Llevas tu identidad válida." or ((v.para or 0) < (v.ucret or A.Ucret) and "No llevas suficientes galeones." or nil),
          function() B.Sor("kimlik.yeni", {}) end)

     local bekle = math.max(0, (v.fotoBekleme or 0) - (RealTime() - (B.VeriAn["kimlik.durum"] or RealTime())))
     Islem("Renovar fotografía", "Si cambiaste pelo o ropa, renueva el retrato animado con tu aspecto actual. Gratis.",
          bekle > 0 and ("Espera · " .. B.Sure(bekle)) or "Renovar", "ikincil", not elde or bekle > 0, not elde and "Debes llevar tu identidad válida." or nil,
          function() B.Sor("kimlik.foto", {}) end)

     cy = cy + 6
     U.Paragraf("Puedes mostrar tu identidad desde el inventario o con el menú L al mirar a alguien. Verá tu nombre. Un agente puede exigirla; negarse es delito.",
          13, 700, sx, cy, sw, R.soluk, 19, 5)
end

-- Rayda yer yok (yüksek kademede 13 sayfa ad kartının üstüne biner): gizli sayfa; Gişe düğmesi, kendi kartının
-- "Nüfus işlemleri" düğmesi ve /Kimlik açar
function K.SayfaAc()
     if not IsValid(B.Defter) then B.Ac() end
     B.Git("kimlik")
end

B.Sayfa("kimlik", {
     ad = "Identidad y padrón", gizli = true,
     alt = "Documento de identidad de mago · Registro Mágico de Población",
     ac = function() B.Sor("kimlik.durum", {}) end,
     geri = function()
          if not IsValid(B.Defter) then return end
          B.Git(B.Defter.gise and "gise" or "kumanda")
          return true
     end,
     ciz = SayfaCiz,
})

----------------------------------------------------------------------------------------
-- Gömülü dokular (uret.py)
----------------------------------------------------------------------------------------
-- OTOMATİK ÜRETİLDİ (~/araclar/kimlik/tasarim/uret.py; SHINE_Bakanlik_Kimlik_Menu_Tasarimi) — elle düzenleme.
local G = SardonBakanlik
G.DokuVeri = G.DokuVeri or {}
G.DokuSurum = G.DokuSurum or {}
G.DokuBoyut = G.DokuBoyut or {}
G.DokuUzanti = G.DokuUzanti or {}
G.DokuSurum["kimlik2_zemin"] = "a81a9b28"
G.DokuBoyut["kimlik2_zemin"] = {1200, 700}
G.DokuUzanti["kimlik2_zemin"] = "jpg"
G.DokuVeri["kimlik2_zemin"] = "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"
G.DokuSurum["kimlik2_baslik"] = "a2e35957"
G.DokuBoyut["kimlik2_baslik"] = {308, 50}
G.DokuUzanti["kimlik2_baslik"] = "png"
G.DokuVeri["kimlik2_baslik"] = "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"
G.DokuSurum["kimlik2_muhur"] = "d3383b1b"
G.DokuBoyut["kimlik2_muhur"] = {96, 96}
G.DokuUzanti["kimlik2_muhur"] = "png"
G.DokuVeri["kimlik2_muhur"] = "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"
