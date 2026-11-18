-- "addons\\sardonbakanlik\\lua\\sardon_bakanlik\\cl_1ortak.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Bakanlık :: sayfaların ortak parçaları (boş durum, ilerleme çubuğu, adımlayıcı,
-- kişi seçme ve kanun maddesi seçme kipleri). Düz Lua.

local B = SardonBakanlik
local U = B.UI
local R = U.R

B.DurumRenk = {
     yeni = R.altinAcik, yolda = R.mavi, yerinde = R.yesil, kapali = R.soluk,
     acik = R.altinAcik, mahkemede = R.mor, bekliyor = R.altinAcik, etkin = R.yesil, red = R.kizil, bitti = R.soluk,
     odendi = R.yesil, gecikti = R.kizil, itiraz = R.mor, gecerli = R.yesil, iptal = R.soluk,
}

B.OncelikRenk = {R.soluk, R.ada, R.altinAcik, R.kizil}

function U.Bos(x, y, w, h, baslik, alt)
     local cy = y + h / 2
     U.BaklavaCizgi(x + w / 2, cy - 34, 12, R.pirinc, 0.8)
     U.Baklava(x + w / 2, cy - 34, 5, R.altin, 0.8)
     U.Yazi(baslik, 15, 600, x + w / 2, cy, R.ada, 1)
     if alt then
          local satirlar = U.Sar(alt, 12, 700, math.min(w - 40, 460))
          for i, s in ipairs(satirlar) do U.Yazi(s, 12, 700, x + w / 2, cy + 8 + i * 18, R.soluk, 1) end
     end
end

function U.Bekleniyor(x, y, w, h)
     local t = RealTime()
     local cx, cy = x + w / 2, y + h / 2
     for i = 0, 2 do
          local a = 0.35 + 0.65 * math.max(0, math.sin(t * 4 - i * 0.9))
          U.Baklava(cx - 22 + i * 22, cy, 5, R.altin, a)
     end
     U.Yazi("El expediente está pasando página…", 12, 700, cx, cy + 26, R.soluk, 1)
end

function U.Cubuk(x, y, w, h, oran, c)
     oran = math.Clamp(oran or 0, 0, 1)
     U.Kutu(x, y, w, h, R.cizgi, 0.3)
     if oran > 0 then U.Kutu(x, y, math.max(1, w * oran), h, c or R.altin, 0.95) end
end

-- − değer + ; Dönüş: yeni değer
function U.Adim(x, y, deger, en, ust, adim, yazi)
     local yeni = deger
     if U.Dugme(x, y, 30, 30, "−", "ikincil", deger <= en) then yeni = math.max(en, deger - adim) end
     U.Kutu(x + 34, y, 110, 30, R.zeminKoyu, 0.7)
     U.Cerceve(x + 34, y, 110, 30, R.cizgi, 0.7)
     U.Yazi(yazi or tostring(deger), 13, 600, x + 89, y + 15, R.fildisi, 1)
     if U.Dugme(x + 148, y, 30, 30, "+", "ikincil", deger >= ust) then yeni = math.min(ust, deger + adim) end
     return yeni
end

-- Anahtar / değer satırı. Dönüş: kullanılan yükseklik
function U.Bilgi(etiket, deger, x, y, w, renk)
     U.Etiket(etiket, x, y, R.soluk, 0, 10)
     U.Yazi(U.Kisalt(tostring(deger), 13, 700, w - 130), 13, 700, x + 130, y, renk or R.fildisi)
     return 24
end

----------------------------------------------------------------------------------------
-- Kişi seçme kipi: arşivde ada göre arar (sicil.ara), seçilince fn(id, ad).
-- Başka bir kipin üstüne açılabilir (alttaki kipin yazdıkları korunur).
----------------------------------------------------------------------------------------
function B.KisiSec(baslik, fn, ipucu)
     local sonSorgu
     B.Veri["sicil.ara"] = nil

     B.Kip({baslik = baslik, w = 560, h = 470, odak = "ksec.ara", onek = "ksec.", ustune = true, ciz = function(x, y, w)
          if ipucu then U.Yazi(ipucu, 12, 700, x, y + 4, R.soluk) end
          local q = U.Girdi("ksec.ara", x, y + 20, w, 36, "Escribe el nombre (mín. 2 letras)…", {maks = 40})
          q = string.Trim(q)
          if q ~= sonSorgu then
               sonSorgu = q
               B.Iste("sicil.ara", {q = q})
          end

          local veri = B.Veri["sicil.ara"]
          local liste = veri and veri.liste or {}
          local ly, lh = y + 66, 340
          local kay = U.Kaydir("ksec.kisiler", x, ly, w, lh, #liste * 40)
          for i, k in ipairs(liste) do
               local sy = ly + (i - 1) * 40 - kay
               if U.Gorunur(sy, 40) then
                    local tik = U.Satir(x, sy, w - 8, 40)
                    U.Baklava(x + 14, sy + 20, 4, k.cevrimici and R.yesil or R.pirinc, 1)
                    U.Yazi(U.Kisalt(k.ad, 14, 600, 300), 14, 600, x + 30, sy + 20, R.fildisi)
                    U.Yazi(U.Kisalt(k.fraksiyon or "", 11, 700, 170), 11, 700, x + w - 20, sy + 20, R.soluk, 2)
                    if tik then
                         U.KaydirBitir()
                         B.KipKapat()
                         fn(k.id, k.ad)
                         return 410
                    end
               end
          end
          U.KaydirBitir()
          if #liste == 0 then U.Bos(x, ly, w, lh, veri and "No se encontró ningún registro" or "Buscando en el archivo…") end
          return 410
     end})
end

----------------------------------------------------------------------------------------
-- Ceza kanunu maddesi seçme kipi: fn(kod)
----------------------------------------------------------------------------------------
function B.KanunSec(baslik, fn, yalnizPara)
     B.Kip({baslik = baslik, w = 760, h = 520, ciz = function(x, y, w)
          local satirlar = {}
          for _, b in ipairs(B.KanunBolumleri) do
               local ilk = true
               for _, m in ipairs(B.Kanun) do
                    if m.bolum == b.id and (not yalnizPara or m.para > 0) then
                         if ilk then
                              satirlar[#satirlar + 1] = {baslik = b.ad}
                              ilk = false
                         end
                         satirlar[#satirlar + 1] = {m = m}
                    end
               end
          end

          local carpan = GetGlobalFloat("SBCezaCarpani", 1)
          local lh = 460
          local toplam = 0
          for _, s in ipairs(satirlar) do toplam = toplam + (s.baslik and 34 or 52) end

          local kay = U.Kaydir("kip.kanun", x, y, w, lh, toplam)
          local sy = y - kay
          for _, s in ipairs(satirlar) do
               if s.baslik then
                    if U.Gorunur(sy, 34) then U.Bolum(s.baslik, x, sy + 20, w - 14) end
                    sy = sy + 34
               else
                    local m = s.m
                    if U.Gorunur(sy, 52) then
                         local tik, ustunde = U.Satir(x, sy, w - 10, 52)
                         U.Yazi(m.kod, 11, 600, x + 12, sy + 17, R.ust, 0, 1.2)
                         U.Yazi(U.Kisalt(m.ad, 14, 600, 430), 14, 600, x + 70, sy + 17, R.fildisi)
                         U.Yazi(U.Kisalt(m.aciklama, 11, 700, 520), 11, 700, x + 70, sy + 37, R.soluk)
                         local ceza = (m.para > 0 and B.Para(math.floor(m.para * carpan)) or "") ..
                              ((m.para > 0 and m.hapis > 0) and "  ·  " or "") .. (m.hapis > 0 and (B.SureUzun(m.hapis) .. " de prisión") or "")
                         U.Yazi(ceza, 12, 600, x + w - 22, sy + 17, m.agir >= 3 and R.kizil or R.altinAcik, 2)
                         if ustunde then U.ipucu = m.aciklama end
                         if tik then
                              U.KaydirBitir()
                              B.KipKapat()
                              fn(m.kod)
                              return lh
                         end
                    end
                    sy = sy + 52
               end
          end
          U.KaydirBitir()
          return lh
     end})
end

-- Yetkisi olmayan düğme için ipucu metni
function B.YetkiIpucu(izin)
     local ok, sebep = B.Yapabilir(LocalPlayer(), izin)
     if ok then return nil end
     return sebep
end
