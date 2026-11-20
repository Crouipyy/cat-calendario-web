-- "addons\\sardonyaratik\\lua\\sardon_yaratik\\cl_7defter_yaratik.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- [sardon] yaratik :: Yaratık Defteri › YARATIKLARIM

local Y = SardonYaratik
local A = Y.Ayar
local D = Y.D
local R = Y.R

local LX, LY, LW, LH = 40, 104, 372, 756
local KART_H, KART_ARA = 82, 8
local MX, MY, MW, MH = 432, 100, 620, 440
local RX, RW = 1072, 488

local DURUM_AD = {
     [D.VIVARYUM] = "Vivaryumda", [D.TAKIP] = "Yanında", [D.OMUZ] = "Omzunda", [D.BINEK] = "Sırtında binici", [D.KAFES] = "Kafeste",
     [D.KULUCKA] = "Kuluçkada", [D.YUMURTA] = "Yumurta · envanterde", [D.OLU] = "Öldü",
     [D.AGIL] = "Ağılda eşiyle", [D.KASE] = "Yumurta · ağıldaki sepette",
}

-- 2026-11-10: kişisel vivaryumu olmayanın "vivaryum" durumundaki yaratığı bir yerde değil, bekliyor
local function DurumAd(k)
     if k.durum == D.VIVARYUM and not (Y.Benim and Y.Benim.vivaryum) then return "Bekliyor (vivaryumun yok)" end
     return DURUM_AD[k.durum]
end

local function Sirala(liste)
     local canli, yumurta, olu = {}, {}, {}
     for _, k in ipairs(liste) do
          if k.durum == D.OLU then olu[#olu + 1] = k
          elseif k.durum == D.YUMURTA or k.durum == D.KULUCKA or k.durum == D.KASE then yumurta[#yumurta + 1] = k
          else canli[#canli + 1] = k end
     end
     local out = {}
     for _, k in ipairs(canli) do out[#out + 1] = k end
     for _, k in ipairs(yumurta) do out[#out + 1] = k end
     if #olu > 0 then out[#out + 1] = {ayrac = "ANILAR"} end
     for _, k in ipairs(olu) do out[#out + 1] = k end
     return out
end

local function Goreli(sn)
     if not sn then return "—" end
     local fark = sn - Y.SunucuZamani()
     if math.abs(fark) < 60 then return "şimdi" end
     if fark > 0 then return Y.SureYazi(fark) .. " sonra" end
     return Y.SureYazi(-fark) .. " önce"
end

local function KayitAdi(k)
     local tur = Y.Tur(k)
     if (k.evre or 0) == 0 then return (tur and tur.ad or "?") .. " Yumurtası" end
     return k.ad or (tur and tur.ad) or "?"
end

-- ihtiyacın 30'a inmesine kalan süre
local function IhtiyacSure(k, tur, anahtar, deger)
     local saat = tur.ihtiyac[anahtar == "a" and "aclik" or (anahtar == "t" and "temizlik" or "sevgi")]
     local hiz = 100 / (saat * 3600) * (k.azalma or 1) * (A.EvreAzalma[k.evre or 1] or 1)
     if deger <= 30 then return 0 end
     return (deger - 30) / hiz
end

------------------------------------------------------------------------ liste

local function ListeCiz(pnl, T, liste)
     T.Kutu(LX, LY, LW, LH)
     local icerik = 0
     for _, k in ipairs(liste) do icerik = icerik + (k.ayrac and 36 or (KART_H + KART_ARA)) end
     local kay = math.min(pnl.kaydir.liste or 0, math.max(0, icerik - LH + 16))
     pnl.kaydir.liste = kay
     pnl.kaydirAlan.liste = {LX, LY, LW, LH, icerik - LH + 16}

     if #liste == 0 then
          local satirlar = T.Sar("Henüz bir yaratığın yok. Yaratık Bakıcısı'ndan bir yumurta alıp vivaryumda kuluçkaya koyabilirsin.", 14, "kitap", LW - 48)
          for i, s in ipairs(satirlar) do T.Yazi(s, 14, "kitap", LX + LW / 2, LY + 60 + (i - 1) * 22, R.sonuk, 1) end
          return
     end

     local sx1, sy1 = pnl:LocalToScreen(T.X(LX), T.Y(LY + 2))
     local sx2, sy2 = pnl:LocalToScreen(T.X(LX + LW), T.Y(LY + LH - 2))
     render.SetScissorRect(sx1, sy1, sx2, sy2, true)
     local y = LY + 10 - kay
     local simdi = Y.SunucuZamani()
     for _, k in ipairs(liste) do
          if k.ayrac then
               T.Yazi(k.ayrac, 11, "baslik", LX + 18, y + 18, R.kilit, 0, 3)
               T.Ton(R.cizgi, 1)
               T.Dolu(LX + 100, y + 18, LW - 120, 1)
               y = y + 36
          else
               local kx, kw = LX + 10, LW - 20
               if y + KART_H > LY and y < LY + LH then
                    local t = pnl:Tahmin(k)
                    local tur = Y.Tur(k)
                    local secili = pnl.secili == k.id
                    local ustunde = pnl:Ustunde(kx, y, kw, KART_H) and y >= LY and y + KART_H <= LY + LH
                    T.Ton(secili and R.satirSecili or (ustunde and Color(22, 38, 29) or R.satir), 1)
                    T.Dolu(kx, y, kw, KART_H)
                    local nr = Y.Nadirlik[k.nadir or 1]
                    T.Ton(k.durum == D.OLU and R.olum or ((k.evre or 0) == 0 and R.kilit or nr.renk), 1)
                    T.Dolu(kx, y, 4, KART_H)
                    if secili then
                         T.Ton(R.altin, 0.8)
                         T.Cerceve(kx, y, kw, KART_H)
                    end

                    T.Yazi(KayitAdi(k), 16, "isim", kx + 16, y + 20, k.durum == D.OLU and R.kilit or R.parlak, 0)
                    local alt = (tur and tur.ad or "?")
                    if (k.evre or 0) >= 1 then alt = alt .. " · " .. Y.Evreler[k.evre].ad end
                    T.Yazi(alt, 12, 400, kx + 16, y + 42, R.sonuk, 0)
                    local durum = DurumAd(k) or k.durum
                    if k.durum == D.KULUCKA then durum = durum .. " · %" .. math.floor(Y.KuluckaIlerleme(k, simdi) * 100) end
                    if k.durum == D.AGIL and k.agil and (k.agil.sure or 0) > 0 then
                         durum = durum .. " · %" .. math.floor(math.Clamp((t.agil and t.agil.huzur or k.agil.huzur or 0) / k.agil.sure, 0, 1) * 100)
                    end
                    T.Yazi(Y.Buyuk(durum), 10, 600, kx + 16, y + 63, k.durum == D.TAKIP and R.tamam or (k.durum == D.KAFES and R.uyari or R.kilit), 0, 1)

                    -- sağda: ihtiyaç çubukları / kuluçka
                    local bx, bw = kx + kw - 110, 96
                    if k.durum == D.KULUCKA then
                         T.Cubuk(bx, y + 38, bw, 6, Y.KuluckaIlerleme(k, simdi), R.uyari)
                    elseif t.ih and k.durum ~= D.OLU and (k.evre or 0) >= 1 then
                         T.Cubuk(bx, y + 22, bw, 5, (t.ih.a or 0) / 100, R.aclik)
                         T.Cubuk(bx, y + 34, bw, 5, (t.ih.t or 0) / 100, R.temizlik)
                         T.Cubuk(bx, y + 46, bw, 5, (t.ih.s or 0) / 100, R.sevgi)
                         if Y.KeseDolu(k) then
                              T.Ton(R.uyari, 1)
                              T.Baklava(bx + bw - 4, y + 64, 4)
                              T.Yazi("ürün", 10, 600, bx + bw - 12, y + 64, R.uyari, 2)
                         end
                    end
                    pnl:Tik(kx, math.max(y, LY), kw, math.min(KART_H, LY + LH - math.max(y, LY)), function()
                         pnl.secili = k.id
                         Y.DefterSecili = k.id
                    end)
               end
               y = y + KART_H + KART_ARA
          end
     end
     render.SetScissorRect(0, 0, 0, 0, false)
end

------------------------------------------------------------------------ orta: model, ad, evreler, ömür

local function ZamanCizelgesi(pnl, T, k, t, tur)
     local y = 650
     local x0, adim = 472, 135
     local evre = k.evre or 0
     local dugum = {
          {ad = "Yumurta", zaman = k.dogum, gecti = evre >= 1},
          {ad = "Bebek", zaman = k.dogum, gecti = evre >= 1},
          {ad = "Genç", zaman = k.zGenc, gecti = evre >= 2},
          {ad = "Yetişkin", zaman = k.zYetiskin, gecti = evre >= 3},
          {ad = "Ölüm", zaman = Y.OlumZamani(t), gecti = k.durum == D.OLU},
     }
     T.Ton(R.cizgi, 1)
     T.Dolu(x0, y, adim * 4, 2)
     for i, d in ipairs(dugum) do
          local x = x0 + (i - 1) * adim
          local simdiki = (i == evre + 1 and k.durum ~= D.OLU) or (i == 5 and k.durum == D.OLU)
          if d.gecti and i < 5 then
               T.Ton(R.altin, 1)
               T.Dolu(x, y, (i < 4 and dugum[i + 1].gecti) and adim or 0, 2)
          end
          T.Ton(simdiki and R.parlak or (d.gecti and R.altin or R.cizgi), 1)
          T.Baklava(x, y + 1, simdiki and 9 or 6)
          if simdiki then T.Isik(x, y, 40, R.altin, 35) end
          T.Yazi(Y.Buyuk(d.ad), 11, "baslik", x, y + 24, simdiki and R.parlak or (d.gecti and R.soluk or R.kilit), 1, 2)

          local alt
          if i == 1 then alt = k.dogum and ("çatladı " .. Goreli(k.dogum)) or nil
          elseif i == 2 then alt = nil
          elseif i == 5 then alt = k.durum == D.OLU and Goreli(k.olumZ) or (d.zaman and ("~" .. Goreli(d.zaman)) or nil)
          elseif d.gecti then alt = Goreli(d.zaman)
          elseif i == evre + 2 then
               local eksik = Y.EvreEksik(t, Y.SunucuZamani())
               alt = #eksik > 0 and table.concat(eksik, " · ") or "yakında"
          end
          if alt then T.Yazi(alt, 10, 400, x, y + 42, R.sonuk, 1) end
     end
end

local function OmurCubugu(pnl, T, k, t)
     if not k.dogum then return end
     local x, y, w = 472, 748, 540
     local simdi = Y.SunucuZamani()
     local omur = A.Omur
     local yasanan = math.Clamp((simdi - k.dogum) / omur, 0, 1)
     local ceza = math.Clamp((t.ceza or 0) / omur, 0, 1)
     T.Yazi("ÖMÜR", 11, "baslik", x, y - 14, R.sonuk, 0, 3)
     T.Ton(R.satir, 1)
     T.Dolu(x, y, w, 10)
     T.Ton(R.soluk, 0.35)
     T.Dolu(x, y, w * yasanan, 10)
     -- kalan (mum)
     local kalanBas = yasanan
     local kalanBit = math.max(kalanBas, 1 - ceza)
     T.Ton(R.altin, 1)
     T.Dolu(x + w * kalanBas, y, w * (kalanBit - kalanBas), 10)
     if ceza > 0 then
          T.Ton(R.hata, 0.9)
          T.Dolu(x + w * (1 - ceza), y, w * ceza, 10)
     end
     -- alev
     if k.durum ~= D.OLU then
          local ax = x + w * kalanBas
          T.Isik(ax, y + 5, 16 + math.sin(RealTime() * 6) * 2, R.ates, 120)
     end
     local kalan = Y.KalanOmur(t, simdi) or 0
     local yazi = k.durum == D.OLU and ("Yaşadığı süre: " .. Y.SureYazi((k.olumZ or simdi) - k.dogum))
          or ("Kalan: " .. Y.SureYazi(kalan))
     if (t.ceza or 0) > 60 then yazi = yazi .. "   ·   ihmal ömründen " .. Y.SureYazi(t.ceza) .. " götürdü" end
     T.Yazi(yazi, 12, 400, x + w, y - 14, (t.ceza or 0) > 3600 and R.hata or R.sonuk, 2)
end

local function OrtaCiz(pnl, T, k, t, tur)
     local yumurta = (k.evre or 0) == 0
     local bg = (tur.renkler[k.renk or 1] or {}).bg or 0
     pnl.model:Ayarla(tur, bg, k.evre, yumurta)

     -- kaide ışığı
     T.Isik(MX + MW / 2, MY + MH - 40, 230, k.durum == D.OLU and R.olum or (Y.Nadirlik[k.nadir or 1] or Y.Nadirlik[1]).renk, 22)
     if pnl.model.eksik then
          T.Yazi("Model içeriği bu bilgisayarda yok (atölye 3826305324).", 13, 400, MX + MW / 2, MY + MH / 2, R.hata, 1)
     elseif k.durum ~= D.OLU then
          local ex, ey = pnl:LocalToScreen(T.X(MX), T.Y(MY))
          pnl.model:Ciz(ex, ey, MW * T.S, MH * T.S, pnl.surukle ~= nil)
          pnl.modelAlan = {MX, MY, MW, MH}
     else
          T.Yazi("✝", 60, 600, MX + MW / 2, MY + MH / 2 - 20, R.olum, 1)
     end

     local ad = KayitAdi(k)
     local nr = Y.Nadirlik[k.nadir or 1]
     T.Yazi(ad, 30, "isim", MX + MW / 2, 562, R.parlak, 1)
     local bilgi = {tur.ad, Y.SinifKod(tur.sinif)}
     if not yumurta then
          bilgi[#bilgi + 1] = nr.ad
          bilgi[#bilgi + 1] = Y.CinsAdi(k.cins)
          bilgi[#bilgi + 1] = Y.RenkAdi(k)
     end
     T.Yazi(table.concat(bilgi, "  ·  "), 13, 600, MX + MW / 2, 596, yumurta and R.sonuk or nr.renk, 1, 1)

     if not yumurta then
          ZamanCizelgesi(pnl, T, k, t, tur)
          OmurCubugu(pnl, T, k, t)
     end
end

------------------------------------------------------------------------ sağ: bilgiler ve eylemler

local function Bolum(T, baslik, y, h)
     T.Kutu(RX, y, RW, h)
     T.Yazi(baslik, 12, "baslik", RX + 18, y + 18, R.altin, 0, 3)
end

local function SatirCubuk(T, x, y, ad, oran, renk, sag, alt)
     T.Yazi(ad, 12, 600, x, y, R.soluk, 0)
     T.Cubuk(x + 92, y - 4, 260, 8, oran, renk)
     if sag then T.Yazi(sag, 12, 600, x + 452, y, R.parlak, 2) end
     if alt then T.Yazi(alt, 10, 400, x + 92, y + 14, R.sonuk, 0) end
end

local function YumurtaBilgi(pnl, T, k, t, tur)
     local K = A.Kulucka
     Bolum(T, "KULUÇKA", 104, 330)
     if k.durum == D.YUMURTA then
          local satir = T.Sar("Bu yumurta envanterinde duruyor. Vivaryuma gidip envanterden 'Kuluçkaya Koy' de. Kuluçka " .. tur.kulucka .. " dakika sürer.", 13, "kitap", RW - 40)
          for i, s in ipairs(satir) do T.Yazi(s, 13, "kitap", RX + 20, 150 + (i - 1) * 21, R.yazi, 0) end
          return
     end
     local simdi = Y.SunucuZamani()
     local ilerleme = Y.KuluckaIlerleme(k, simdi)
     local sure = Y.KuluckaSure(k)
     SatirCubuk(T, RX + 20, 156, "İlerleme", ilerleme, R.uyari, "%" .. math.floor(ilerleme * 100),
          ilerleme < 1 and ("çatlamasına " .. Y.SureYazi(k.ku.bas + sure - simdi)) or "çatlıyor...")

     local s = t.ku and t.ku.s or 0
     local sRenk = s < K.iyiAlt and R.temizlik or (s > K.iyiUst and R.hata or R.tamam)
     SatirCubuk(T, RX + 20, 202, "Sıcaklık", s / 100, sRenk, string.format("%.0f°", s),
          s < K.iyiAlt and "soğuk — yumurtaya bakıp E › Isıt" or (s > K.iyiUst and "fazla sıcak, soğumasını bekle" or "ideal aralıkta"))
     T.Ton(R.tamam, 0.9)
     T.Cerceve(RX + 112 + 260 * K.iyiAlt / 100, 196, 260 * (K.iyiUst - K.iyiAlt) / 100, 12)

     local cv = (t.ku and t.ku.cevir) or 0
     local aralik = math.floor(Y.CevirAraligi(k))
     local kc = Y.EylemKalan(k, "cevir", aralik)
     SatirCubuk(T, RX + 20, 248, "Çevirme", cv / K.cevirSayisi, R.soluk, cv .. "/" .. K.cevirSayisi,
          cv >= K.cevirSayisi and "tamam" or (kc > 0 and ("sonraki: " .. Y.SureYazi(kc)) or "şimdi çevirebilirsin"))

     -- şimdiye kadarki gidişat (toplam süreye bölmek yarı yolda düşük gösterirdi)
     local gecen = math.max(1, math.min(simdi, k.ku.bas + sure) - k.ku.bas)
     local sicakOran = math.Clamp(((t.ku and t.ku.iyi) or 0) / gecen, 0, 1)
     local beklenen = math.max(1, math.min(K.cevirSayisi, math.floor(gecen / math.max(aralik, 1))))
     local kalite = 0.65 * sicakOran + 0.35 * math.Clamp(cv / beklenen, 0, 1)
     SatirCubuk(T, RX + 20, 294, "Gidişat", kalite, kalite >= K.kusursuz and R.uyari or R.bag, "%" .. math.floor(kalite * 100),
          "kusursuz kuluçka (%" .. math.floor(K.kusursuz * 100) .. "+) yavruyu bir üst nadirliğe çıkarabilir")

     local havuz = k.havuz or {1, 1}
     local adlar = {}
     for _, n in ipairs(havuz) do adlar[#adlar + 1] = (Y.Nadirlik[n] or Y.Nadirlik[1]).ad end
     T.Yazi("Ebeveynler: " .. table.concat(adlar, " + "), 12, 600, RX + 20, 350, R.soluk, 0)
     local satir = T.Sar("Yavru, ebeveynlerden birinin nadirliğini eşit ihtimalle alır. Isıtma iyi aralığın dışına taşarsa ya da çevirme aksarsa kalite düşer.", 12, "kitap", RW - 40)
     for i, s2 in ipairs(satir) do T.Yazi(s2, 12, "kitap", RX + 20, 376 + (i - 1) * 19, R.sonuk, 0) end
end

local function OluBilgi(pnl, T, k, t, tur)
     Bolum(T, "ANISINA", 104, 260)
     local yasadi = Y.SureYazi((k.olumZ or Y.SunucuZamani()) - (k.dogum or 0))
     local sebep = k.olumSebep == "ihmal" and "bakımsızlıktan" or (k.olumSebep == "yonetim" and "bir yetkilinin kararıyla" or "yaşlılıktan, huzur içinde")
     local metin = (k.ad or tur.ad) .. " " .. yasadi .. " yaşadı ve " .. sebep .. " öldü."
     if k.teslimBekliyor then metin = metin .. " Geride bıraktıkları bir sonraki girişinde sana ulaşacak." end
     local satir = T.Sar(metin, 15, "kitap", RW - 40)
     for i, s in ipairs(satir) do T.Yazi(s, 15, "kitap", RX + 20, 150 + (i - 1) * 24, R.yazi, 0) end
end

local function CanliBilgi(pnl, T, k, t, tur)
     local simdi = Y.SunucuZamani()

     -- ihtiyaçlar
     Bolum(T, "İHTİYAÇLAR", 104, 168)
     local ih = t.ih or {}
     local function Eta(an, v, fiil)
          local s = IhtiyacSure(t, tur, an, v)
          return s > 0 and ("~" .. Y.SureYazi(s) .. " sonra " .. fiil) or ("şimdi " .. fiil)
     end
     SatirCubuk(T, RX + 20, 152, "Açlık", (ih.a or 0) / 100, R.aclik, "%" .. math.floor(ih.a or 0), Eta("a", ih.a or 0, "acıkır"))
     SatirCubuk(T, RX + 20, 194, "Temizlik", (ih.t or 0) / 100, R.temizlik, "%" .. math.floor(ih.t or 0), Eta("t", ih.t or 0, "kirlenir"))
     SatirCubuk(T, RX + 20, 236, "Sevgi", (ih.s or 0) / 100, R.sevgi, "%" .. math.floor(ih.s or 0), Eta("s", ih.s or 0, "ilgi ister"))
     T.Yazi("Sever: " .. Y.BesinYazi(tur), 11, 400, RX + RW - 18, 118, R.sonuk, 2)

     -- bağ ve eğitim
     Bolum(T, "BAĞ VE EĞİTİM", 284, 140)
     SatirCubuk(T, RX + 20, 330, "Bağ", (t.bag or 0) / 100, R.bag, math.floor(t.bag or 0) .. "/100",
          (simdi - (k.ilgi or simdi)) > A.IlgiSuresi and "uzun süredir ilgilenilmedi, bağ zayıflıyor" or "bakım ve sevgiyle güçlenir")
     local sev, il = Y.Seviye(k.xp)
     SatirCubuk(T, RX + 20, 372, "Eğitim", sev >= A.EnFazlaSeviye and 1 or il, R.egitim, "Sv " .. sev .. "/" .. A.EnFazlaSeviye,
          sev >= A.EnFazlaSeviye and "eğitimi tamamlandı" or ("%" .. math.floor(il * 100) .. " · E › Eğit"))
     local eksik = Y.EvreEksik(t, simdi)
     if #eksik > 0 then
          T.Yazi("Büyümesi için: " .. table.concat(eksik, " · "), 11, 600, RX + 20, 406, R.uyari, 0)
     end

     -- ürün
     Bolum(T, "ÜRÜN KESESİ", 436, 132)
     local parcalar = {}
     for ad, n in pairs(k.kese or {}) do if n > 0 then parcalar[#parcalar + 1] = n .. " " .. ad end end
     if (k.keseG or 0) > 0 then parcalar[#parcalar + 1] = math.floor(k.keseG) .. " Galleon" end
     T.Yazi(#parcalar > 0 and table.concat(parcalar, ", ") or "Kese boş", 13, #parcalar > 0 and 600 or 400, RX + 20, 482, #parcalar > 0 and R.uyari or R.sonuk, 0)
     local u = tur.urun
     if u then
          local urunAd = u.galleon and "Galleon" or u.ad
          if (k.evre or 0) < 2 then
               T.Yazi(urunAd .. " vermesi için gençleşmeli.", 11, 400, RX + 20, 514, R.sonuk, 0)
          else
               local aralik = u.aralik * 3600
               local mutlu = Y.Mutluluk(t)
               T.Cubuk(RX + 20, 508, RW - 40, 5, (t.urunSn or 0) / aralik, mutlu >= A.UrunMutluluk and R.uyari or R.cizgi)
               T.Yazi(mutlu >= A.UrunMutluluk and ("Sonraki " .. urunAd .. ": ~" .. Y.SureYazi(aralik - (t.urunSn or 0)) .. " mutlu kalırsa")
                    or ("Ürün için mutluluk %" .. A.UrunMutluluk .. "+ olmalı (şu an %" .. math.floor(mutlu) .. ")"), 11, 400, RX + 20, 530, R.sonuk, 0)
          end
     end

     -- eylemler
     Bolum(T, "EYLEMLER", 580, 280)
     local x1, x2, bw, bh = RX + 20, RX + RW / 2 + 6, RW / 2 - 26, 40
     local y = 612
     local kafeste = k.durum == D.KAFES
     local id = k.id
     if tur.rol.takip then
          if k.durum == D.TAKIP then
               pnl:Dugme(x1, y, bw, bh, (Y.Benim and Y.Benim.vivaryum) and "Vivaryuma Gönder" or "Yanımdan Gönder", function() Y.Islem("gonder", id) end)
          else
               pnl:Dugme(x1, y, bw, bh, "Yanıma Çağır", function() Y.Islem("cagir", id) end, not kafeste, true)
          end
     else
          pnl:Dugme(x1, y, bw, bh, "Yürüyemez", nil, false)
     end
     if tur.rol.omuz then
          if k.durum == D.OMUZ then
               pnl:Dugme(x2, y, bw, bh, "Omzundan İndir", function() Y.Islem("omuz_indir", id) end)
          else
               pnl:Dugme(x2, y, bw, bh, "Omzuna Al", function() Y.Islem("omuz", id) end, not kafeste)
          end
     else
          pnl:Dugme(x2, y, bw, bh, "Omza Sığmaz", nil, false)
     end
     y = y + bh + 10
     pnl:Dugme(x1, y, bw, bh, "Kafese Koy", function() Y.Islem("kafes", id) end, not kafeste and Y.EsyaVarMi("yaratik_kafes", true))
     pnl:Dugme(x2, y, bw, bh, "Adlandır", function()
          Derma_StringRequest("Yaratığa ad ver", "Yeni adı (2-24 harf):", k.ad or tur.ad, function(metin)
               Y.Islem("adlandir", id, metin)
          end, nil, "Kaydet", "Vazgeç")
     end)
     y = y + bh + 10
     local toplanir = Y.KeseDolu(k) and (k.durum == D.TAKIP or k.durum == D.OMUZ)
     pnl:Dugme(x1, y, bw, bh, "Ürünleri Topla", function() Y.Islem("topla", id) end, toplanir)
     if tur.rol.binek then
          pnl:Dugme(x2, y, bw, bh, k.binisAcik and "Binişi Kapat" or "Binişe Aç", function() Y.Islem("binis_izin", id) end, not kafeste)
     end

     local not_ = kafeste and "Kafeste: kafes envanterdeyken 'Vivaryuma Bırak' ile geri döner. Kafesi alan karakter yeni sahibi olur."
          or (tur.rol.binek and (k.baygin or 0) > Y.SunucuZamani()
               and ("Bayıldı; " .. Y.SureYazi(k.baygin - Y.SunucuZamani()) .. " dinlenecek. Bakım ve binme yaratığın yanında: ona bakıp E.")
          or (tur.rol.binek and "Binmek, selam vermek ve bakım yaratığın yanında: ona bakıp E. Yalnız yetişkin bineklere binilir; uçmak SYB › Binicilik ister."
          or "Besleme, fırçalama ve eğitim yaratığın yanında: ona bakıp E. Ürünleri yanındayken buradan da toplayabilirsin."))
     local satir = T.Sar(not_, 11, 400, RW - 40)
     for i, s in ipairs(satir) do T.Yazi(s, 11, 400, RX + 20, y + bh + 22 + (i - 1) * 17, R.sonuk, 0) end
end

------------------------------------------------------------------------ sekme

Y.DefterCiz.yaratiklar = function(pnl, T, w, h)
     local liste = Sirala((Y.Benim and Y.Benim.liste) or {})
     -- seçim
     local secili
     for _, k in ipairs(liste) do
          if not k.ayrac and k.id == (pnl.secili or Y.DefterSecili) then secili = k end
     end
     if not secili then
          for _, k in ipairs(liste) do if not k.ayrac then secili = k break end end
     end
     pnl.secili = secili and secili.id

     ListeCiz(pnl, T, liste)
     if not secili then
          pnl.model:Kaldir()
          T.Yazi("Sihirli yaratıkların burada görünür.", 18, "kitap", 1060, 440, R.sonuk, 1)
          return
     end

     local tur = Y.Tur(secili)
     if not tur then return end
     local t = pnl:Tahmin(secili)
     OrtaCiz(pnl, T, secili, t, tur)

     if secili.durum == D.OLU then
          OluBilgi(pnl, T, secili, t, tur)
     elseif (secili.evre or 0) == 0 then
          YumurtaBilgi(pnl, T, secili, t, tur)
     else
          CanliBilgi(pnl, T, secili, t, tur)
     end
end
