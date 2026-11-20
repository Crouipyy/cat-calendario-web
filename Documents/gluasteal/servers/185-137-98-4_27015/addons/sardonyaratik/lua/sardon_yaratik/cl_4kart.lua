-- "addons\\sardonyaratik\\lua\\sardon_yaratik\\cl_4kart.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- [sardon] yaratik :: bakış kartları (V2)
--
-- Etkileşim mesafesindeki, görülen hedefe bakınca hafif bir kart: yaratıkta tüy silüeti (feather_card),
-- yumurtada kuluçka madalyonlu damla (egg_card). Kart hedefin baş noktasının izdüşümünün yanına
-- konur (yüzünü kapatmaz); nokta kameranın arkasındaysa kart çizilmez. Değerler her karede o anki
-- varlıktan okunur; hedef değişince kart sıfırdan belirir. Değer arttığında (beslenince, ısıtılınca)
-- çubuğun ucundan kısa bir kıvılcım çıkar. Altta yalnız gerçek bağa (+use) bağlı tek ipucu.

local Y = SardonYaratik
local A = Y.Ayar
local V = Y.V2
local R = V.R

local math_max, math_min, math_floor, math_Clamp = math.max, math.min, math.floor, math.Clamp

local K = {ent = nil, yemlik = nil, tip = nil, a = 0, x = nil, y = nil, once = {}}

local function Benim(ent) return ent:GetSahip() == LocalPlayer() end

------------------------------------------------------------------------ yumurta konturu (madalyon)

-- egg_progress_track.svg yolu (128×160): tepeden başlayıp önce sola, saat yönünün tersine.
-- Eşit yay uzunluğunda örneklenir; ilerleme bu çizgi boyunca gerçek yüzdeyle çizilir.
local KONTUR = {}
do
     local parcalar = {
          {64, 8, 46, 8, 14, 60, 14, 97}, {14, 97, 14, 128, 35, 150, 64, 150},
          {64, 150, 93, 150, 114, 128, 114, 97}, {114, 97, 114, 60, 82, 8, 64, 8},
     }
     local ham, boy = {}, {0}
     for _, c in ipairs(parcalar) do
          for i = (#ham == 0 and 0 or 1), 40 do
               local t = i / 40
               local u = 1 - t
               local x = u ^ 3 * c[1] + 3 * u * u * t * c[3] + 3 * u * t * t * c[5] + t ^ 3 * c[7]
               local y = u ^ 3 * c[2] + 3 * u * u * t * c[4] + 3 * u * t * t * c[6] + t ^ 3 * c[8]
               ham[#ham + 1] = {x, y}
               if #ham > 1 then
                    local o = ham[#ham - 1]
                    boy[#ham] = boy[#ham - 1] + math.sqrt((x - o[1]) ^ 2 + (y - o[2]) ^ 2)
               end
          end
     end
     local toplam = boy[#ham]
     local N, j = 96, 1
     for i = 0, N do
          local hedef = toplam * i / N
          while j < #ham - 1 and boy[j + 1] < hedef do j = j + 1 end
          local f = (hedef - boy[j]) / math_max(boy[j + 1] - boy[j], 1e-6)
          KONTUR[i + 1] = {ham[j][1] + (ham[j + 1][1] - ham[j][1]) * f, ham[j][2] + (ham[j + 1][2] - ham[j][2]) * f}
     end
end

-- kart içindeki madalyon: kontur merkezi (64,79) → (76,106.5), eş ölçek 0.92
local MK, MX, MY = 0.92, 76, 106.5

local function Madalyon(x0, y0, s, oran, a)
     local k = MK * s
     local tx, ty = x0 + (MX - 64 * MK) * s, y0 + (MY - 79 * MK) * s
     if not V.Doku("egg_progress_track", tx, ty, 128 * k, 160 * k, nil, a) then
          for i = 1, #KONTUR - 1 do
               local p, q = KONTUR[i], KONTUR[i + 1]
               V.Cizgi(tx + p[1] * k, ty + p[2] * k, tx + q[1] * k, ty + q[2] * k, 2 * s, R.izYumurta, a)
          end
     end
     if not oran or oran <= 0 then return end
     local n = math_floor((#KONTUR - 1) * math_min(oran, 1))
     local t = math_max(2, 3.5 * s)
     for i = 1, n do
          local p, q = KONTUR[i], KONTUR[i + 1]
          V.Cizgi(tx + p[1] * k, ty + p[2] * k, tx + q[1] * k, ty + q[2] * k, t, R.altin, a)
     end
     local son = KONTUR[n + 1]
     return tx + son[1] * k, ty + son[2] * k
end

------------------------------------------------------------------------ ortak parçalar

-- kartın ölçeği: tasarım boyu, küçük ekranda 0,8'in altına inmez
local function Olcek() return math_max(V.Olcek(), 0.8) end

local function Ipucu(x, y, s, a, tus, yazi, uzak)
     if uzak then
          V.Yazi("Yaklaş", V.Font("govde", 15, s), x, y + 17 * s, R.ikincil, a, 0)
          return
     end
     if not tus then
          V.Yazi(yazi, V.Font("govde", 14, s), x, y + 17 * s, R.ikincil, a, 0)
          return
     end
     local f = V.Font("govde", 12, s)
     local tw = math_max(25 * s, V.Olcu(tus, f) + 14 * s)
     V.TusKapagi(x, y, tw, 23 * s, s, a)
     V.Yazi(tus, f, x + tw / 2, y + 16 * s, R.yazi, a, 1)
     V.Yazi(yazi, V.Font("govde", 15, s), x + tw + 11 * s, y + 17 * s, R.yazi, a, 0)
end

local function KullanTus() return V.TusAdi("+use", "E") end

-- tüy kartı satırı: oran verilirse 3 px çubuk, yoksa yalnız değer yazısı
local function Satir(x0, y0, s, a, j, st)
     local ty = y0 + (99 + (j - 1) * 28) * s
     if st.orijinal then
          V.Doku(st.ikon, x0 + 57 * s, ty - 14 * s, 19 * s, 19 * s, nil, a)
     else
          V.Ikon(st.ikon, x0 + 66.5 * s, ty - 4.5 * s, 19 * s, st.renk or R.altin, a)
     end
     local f = V.Font("govde", 15, s)
     V.Yazi(V.Kisalt(st.ad, f, 90 * s), f, x0 + 83 * s, ty, R.ikincil, a, 0)
     if st.oran then
          V.Cubuk(x0 + 177 * s, ty - 6 * s, 129 * s, math_max(2, 3 * s), st.oran, st.renk, a)
          V.Yazi(st.deger, f, x0 + 368 * s, ty, st.degerRenk or R.yazi, a, 2)
          return x0 + (177 + 129 * math_Clamp(st.oran, 0, 1)) * s, ty - 5 * s
     end
     V.Yazi(V.Kisalt(st.deger or "", f, 190 * s), f, x0 + 368 * s, ty, st.degerRenk or R.yazi, a, 2)
end

local function TuyKart(x0, y0, s, a, v)
     if not V.Doku("feather_card", x0, y0, 400 * s, 250 * s, nil, a) then
          draw.NoTexture()
          surface.SetDrawColor(R.zemin.r, R.zemin.g, R.zemin.b, 235 * a)
          surface.DrawRect(x0 + 5 * s, y0 + 20 * s, 393 * s, 212 * s)
          surface.SetDrawColor(R.altin.r, R.altin.g, R.altin.b, 120 * a)
          surface.DrawRect(x0 + 66 * s, y0 + 30 * s, 300 * s, 1)
     end
     V.Ikon(v.ikon or "feather", x0 + 42 * s, y0 + 37 * s, 28 * s, R.altin, a)

     -- nadirlik sağa yaslı (baklava + ad), alt satır kalan yere sığar
     local fN = V.Font("govde", 13, s)
     local nw = 0
     if v.nadir then
          nw = V.Olcu(v.nadir, fN)
          V.Yazi(v.nadir, fN, x0 + 372 * s, y0 + 75 * s, v.nadirRenk or R.altin, a, 2)
          V.Baklava(x0 + 372 * s - nw - 10 * s, y0 + 71 * s, 3 * s, v.nadirRenk or R.altin, a, false)
          nw = nw + 22 * s
     end
     local fAd = V.Font("baslik", 26, s)
     V.Yazi(V.Kisalt(v.ad, fAd, 300 * s), fAd, x0 + 69 * s, y0 + 51 * s, R.yazi, a, 0)
     local fAlt = V.Font("govde", 14, s)
     V.Yazi(V.Kisalt(v.alt or "", fAlt, 303 * s - nw), fAlt, x0 + 69 * s, y0 + 75 * s, v.altRenk or R.ikincil, a, 0)

     local uclar = {}
     for j, st in ipairs(v.satir or {}) do
          if j > 4 then break end
          local ux, uy = Satir(x0, y0, s, a, j, st)
          uclar[j] = ux and {ux, uy} or nil
     end
     Ipucu(x0 + 72 * s, y0 + 199 * s, s, a, v.tus, v.ipucu, v.uzak)
     return uclar
end

------------------------------------------------------------------------ içerik

local function NadirBilgi(ent)
     local n = math_Clamp(ent:GetNadir(), 1, 3)
     return (Y.Nadirlik[n] or Y.Nadirlik[1]).ad, V.NadirRenk[n]
end

local function YaratikVeri(ent, tur, benim, uzak)
     local v = {ad = (ent:GetAd() ~= "" and ent:GetAd()) or tur.ad}
     v.nadir, v.nadirRenk = NadirBilgi(ent)
     v.alt = tur.ad .. " · " .. ((Y.Evreler[ent:GetEvre()] or {}).ad or "")
     v.uzak = uzak
     if benim then
          local k = Y.BenimKayit(ent:GetKimlik())
          local a, t, sv = ent:IhtiyacCoz()
          local bag = k and math.Round(k.bag or 0)
          local function D(x) return x < 20 and R.can or nil end
          v.satir = {
               {ikon = "feed", ad = "Tokluk", deger = "%" .. a, oran = a / 100, renk = R.altin, degerRenk = D(a), anahtar = "a", ham = a},
               {ikon = "brush", ad = "Temizlik", deger = "%" .. t, oran = t / 100, renk = R.enerji, degerRenk = D(t), anahtar = "t", ham = t},
               {ikon = "heart", ad = "Sevgi", deger = "%" .. sv, oran = sv / 100, renk = R.can, degerRenk = D(sv), anahtar = "s", ham = sv},
               {ikon = "bond_rhombus", orijinal = true, ad = "Bağ", deger = bag and ("%" .. bag) or "—", oran = (bag or 0) / 100, renk = R.bag, anahtar = "b", ham = bag},
          }
          local simdi = Y.SunucuZamani()
          if ent:GetDurum() == Y.ENT_AGIL then
               local ag = k and k.agil
               local yuzde = ag and (ag.sure or 0) > 0 and math_floor(math_Clamp((ag.huzur or 0) / ag.sure, 0, 1) * 100)
               v.alt = "Çiftleşme Ağılı" .. (yuzde and (" · %" .. yuzde) or "")
               v.altRenk = R.can
          elseif k and (k.baygin or 0) > simdi then
               v.alt = "Kendine geliyor · " .. Y.SureYazi(k.baygin - simdi)
               v.altRenk = R.can
          end
          if Y.CizimEngeli and Y.CizimEngeli(ent) then v.alt = "Göremiyorsun · yalnız hissediyorsun" end
          v.tus, v.ipucu = KullanTus(), "Bakım"
     else
          local sahip = ent:GetSahip()
          v.satir = {{ikon = "follow", ad = "Sahibi", deger = IsValid(sahip) and sahip:Nick() or "—", renk = R.ikincil}}
          local binek = tur.rol and tur.rol.binek and ent:GetEvre() >= 3 and ent:GetDurum() ~= Y.ENT_AGIL
          if binek then
               v.satir[2] = {ikon = "ride", ad = "Biniş", deger = ent:GetTur() == "hippogriff" and "Önce selam ister" or "Sahibinin izniyle", renk = R.altin}
               v.tus, v.ipucu = KullanTus(), ent:GetTur() == "hippogriff" and "Selam / Bin" or "Sev / Bin"
          else
               v.tus, v.ipucu = KullanTus(), "Sev"
          end
     end
     return v
end

local function CantaDayanim()
     local char = LocalPlayer():GetCharacter()
     local inv = char and char:GetInventory()
     if not inv then return end
     local en
     for _, it in pairs(inv:GetItemsByUniqueID("yaratik_cuval", true) or {}) do
          local d = it:GetData("dayanim", A.Yabani.CantaDayanim)
          if not en or d > en then en = d end
     end
     return en
end

local function YabaniVeri(ent, tur, uzak)
     local sersem = ent:GetDurum() == Y.ENT_SERSEM
     local v = {ad = "Yabani " .. tur.ad, uzak = uzak and sersem}
     v.nadir, v.nadirRenk = NadirBilgi(ent)
     local cins = ent:GetNW2String("SYCins", "")
     v.alt = ((Y.Evreler[ent:GetEvre()] or {}).ad or "") .. (cins ~= "" and (" · " .. Y.CinsAdi(cins)) or "")
     local sinif = Y.Siniflar[tur.sinif or 1] or Y.Siniflar[1]
     local canta = CantaDayanim()
     v.satir = {
          {ikon = "shield", ad = "Durum", deger = sersem and "Sersem" or "Uyanık", renk = R.altin, degerRenk = sersem and R.altin or R.ikincil},
          {ikon = "feather", ad = "Bakanlık", deger = sinif.kod .. " · " .. (sinif.ad:match("^(.-) /") or sinif.ad), renk = R.ikincil},
          {ikon = "collect", ad = "Çanta", deger = canta and (canta .. "/" .. A.Yabani.CantaDayanim) or "Yok", renk = R.altin, degerRenk = not canta and R.can or nil},
     }
     if sersem then
          if canta then v.tus, v.ipucu = KullanTus(), "Basılı tut · Yakala" else v.ipucu = "Yakalama Çantası gerek" end
     else
          v.ipucu = "Önce sersemlet: Stupefy, Arresto..."
     end
     return v
end

local function YemlikVeri(i, uzak)
     local stok = (Y.Benim and Y.Benim.yemlik) or {}
     local v = {ad = "Yemlik", alt = "Senin stoğun · sen yokken buradan yerler", ikon = "feed", uzak = uzak}
     v.satir = {}
     for _, yem in ipairs(Y.YemSirasi) do
          local n = stok[yem] or 0
          if n > 0 and Y.Yemler[yem] then
               v.satir[#v.satir + 1] = {ikon = "feed", ad = Y.Yemler[yem].ad, deger = n .. "/" .. A.YemlikSiniri, oran = n / A.YemlikSiniri,
                    renk = R.altin, anahtar = yem, ham = n}
          end
     end
     if #v.satir == 0 then v.satir[1] = {ikon = "feed", ad = "Boş", deger = "Yem koy", renk = R.can, degerRenk = R.can} end
     if #v.satir > 4 then
          local fazla = #v.satir - 3
          for j = #v.satir, 5, -1 do v.satir[j] = nil end
          v.satir[4] = {ikon = "feed", ad = "Diğer", deger = "+" .. fazla .. " tür", renk = R.altin}
     end
     v.tus, v.ipucu = KullanTus(), "Yem koy"
     return v
end

------------------------------------------------------------------------ yumurta kartı

local function YumurtaKart(x0, y0, s, a, ent, tur, benim, uzak)
     if not V.Doku("egg_card", x0, y0, 420 * s, 250 * s, nil, a) then
          draw.NoTexture()
          surface.SetDrawColor(R.zemin.r, R.zemin.g, R.zemin.b, 235 * a)
          surface.DrawRect(x0 + 12 * s, y0 + 76 * s, 398 * s, 160 * s)
     end
     local kasede = ent:GetDurum() == Y.ENT_KASE
     local k = benim and Y.BenimKayit(ent:GetKimlik())
     local KU = A.Kulucka
     local fAd = V.Font("baslik", 26, s)
     V.Yazi(V.Kisalt(tur.ad, fAd, 247 * s), fAd, x0 + 143 * s, y0 + 114 * s, R.yazi, a, 0)
     V.Yazi("Yumurtası", V.Font("baslik", 22, s), x0 + 143 * s, y0 + 141 * s, R.yazi, a, 0)

     local fAlt = V.Font("govde", 14, s)
     local alt, altRenk = "Kuluçka", R.ikincil
     local oran
     if kasede then
          alt = "Ağıldaki saman sepetinde"
     else
          oran = math_Clamp((CurTime() - ent:GetKBas()) / math_max(ent:GetKSure(), 1), 0, 1)
          if benim then
               local kalan = math_max(0, ent:GetKBas() + ent:GetKSure() - CurTime())
               alt = kalan > 60 and ("Kuluçka · " .. Y.SureYazi(kalan) .. " kaldı") or "Çatlamak üzere"
               if ent.YCevirVakti then alt, altRenk = "Çevirme vakti · " .. (kalan > 60 and Y.SureYazi(kalan) or "az kaldı"), R.altin end
          else
               local sahip = ent:GetSahip()
               alt = "Kuluçka" .. (IsValid(sahip) and (" · " .. sahip:Nick()) or "")
          end
     end
     V.Yazi(V.Kisalt(alt, fAlt, 247 * s), fAlt, x0 + 143 * s, y0 + 164 * s, altRenk, a, 0)

     -- madalyon: gerçek ilerleme (yalnız sahibine), ortada ikon ve yüzde
     local ux, uy = Madalyon(x0, y0, s, benim and oran or nil, a)
     V.Ikon(kasede and "collect" or "egg", x0 + 76 * s, y0 + 97 * s, 34 * s, R.altin, a)
     if benim and oran then
          V.Yazi("%" .. math_floor(oran * 100), V.Font("baslik", 23, s), x0 + 76 * s, y0 + 140 * s, R.yazi, a, 1)
     end

     local uclar = {}
     if benim and not kasede then
          -- sıcaklık bandı: ideal aralık, şimdiki değer imleci, ayrı durum yazısı (birim yok: oyun 0-100 ölçeği)
          local sicak = Y.KuluckaSicakNow(ent)
          local durum, dRenk = "İdeal", R.olumlu
          if sicak < KU.iyiAlt then durum, dRenk = "Soğuk", R.enerji elseif sicak > KU.iyiUst then durum, dRenk = "Sıcak", R.can end
          V.Ikon("temperature", x0 + 152.5 * s, y0 + 189.5 * s, 19 * s, R.enerji, a)
          local f = V.Font("govde", 14, s)
          V.Yazi("Sıcaklık", f, x0 + 169 * s, y0 + 195 * s, R.ikincil, a, 0)
          V.Yazi(durum, f, x0 + 388 * s, y0 + 195 * s, dRenk, a, 2)
          local bx, bw = x0 + 146 * s, 242 * s
          local function X(d) return bx + bw * math_Clamp((d - KU.taban) / (100 - KU.taban), 0, 1) end
          V.Cubuk(bx, y0 + 205 * s, bw, math_max(3, 5 * s), 0, R.iz, a)
          local ix0, ix1 = X(KU.iyiAlt), X(KU.iyiUst)
          draw.NoTexture()
          surface.SetDrawColor(R.ideal.r, R.ideal.g, R.ideal.b, 255 * a)
          surface.DrawRect(ix0, y0 + 203 * s, ix1 - ix0, 9 * s)
          surface.SetDrawColor(R.olumlu.r, R.olumlu.g, R.olumlu.b, 255 * a)
          surface.DrawOutlinedRect(ix0, y0 + 203 * s, ix1 - ix0, math_max(4, 9 * s), 1)
          V.Yazi("İdeal", V.Font("govde", 10, s), (ix0 + ix1) / 2, y0 + 222 * s, R.olumlu, a, 1)
          local mx = X(sicak)
          if not V.Doku("temperature_marker", mx - 7 * s, y0 + 200.5 * s, 14 * s, 14 * s, nil, a) then
               V.Baklava(mx, y0 + 207.5 * s, 5 * s, R.yazi, a)
          end
          uclar.sicak = {mx, y0 + 203 * s, sicak}
          -- ipucu solda, madalyonun altında
          Ipucu(x0 + 45 * s, y0 + 186 * s, s, a, not uzak and KullanTus() or nil, "Bakım", uzak)
     elseif benim and kasede then
          local kalan = k and k.kase and math_max(0, (k.kase.z or 0) + A.Ureme.KaseBekle - Y.SunucuZamani())
          local f = V.Font("govde", 14, s)
          V.Yazi(kalan and ("Alınmazsa " .. Y.SureYazi(kalan) .. " sonra soğur") or "Sepette bekliyor", f, x0 + 146 * s, y0 + 200 * s, R.ikincil, a, 0)
          Ipucu(x0 + 45 * s, y0 + 186 * s, s, a, not uzak and KullanTus() or nil, "", uzak)
          V.Yazi(uzak and "" or "Yumurtayı al", f, x0 + 146 * s, y0 + 222 * s, R.yazi, a, 0)
     end
     uclar.oran = ux and {ux, uy, oran} or nil
     return uclar
end

------------------------------------------------------------------------ çizim

local function Sec()
     if IsValid(Y.Radyal) or Y.OyunAcik then return end
     if Y.Biniyor and Y.Biniyor(LocalPlayer()) then return end
     local ent = Y.Hedef()
     if ent then
          local tur = ent:TurVeri()
          if not tur then return end
          local benim = Benim(ent)
          if Y.CizimEngeli and Y.CizimEngeli(ent) and not benim then return end
          local p = ent:CizimKonumu()
          local _, _, h = Y.VarlikKutu(ent)
          local tip
          if Y.YabaniMi(ent) then tip = "yabani"
          elseif ent:GetEvre() == 0 then tip = "yumurta"
          else tip = "yaratik" end
          return ent, nil, tip, p + Vector(0, 0, (h or 30) + 10)
     end
     local i = Y.YemlikHedef()
     if i and Y.Alan.yemlik and Y.Alan.yemlik[i] then
          return nil, i, "yemlik", Y.Alan.yemlik[i] + Vector(0, 0, 52)
     end
end

-- değer artınca çubuğun ucundan kıvılcım (aynı hedefte, gerçek artış)
local function Artislar(uclar, satirlar, s)
     for j, st in ipairs(satirlar or {}) do
          if st.anahtar and st.ham then
               local o = K.once[st.anahtar]
               if o and st.ham > o + 0.5 and uclar[j] then
                    V.Kivilcim("hud", uclar[j][1], uclar[j][2], st.renk == R.altin and R.altin or st.renk, 7, 55, 0.7, 13, s, -math.pi / 2, 1.6)
               end
               K.once[st.anahtar] = st.ham
          end
     end
end

hook.Add("HUDPaint", "SardonYaratik.Kart", function()
     local ent, yemlik, tip, nokta = Sec()
     local dt = math_min(RealFrameTime(), 0.05)

     -- hedef değişti: yeni kart sıfırdan belirir, eski değerler taşınmaz
     if ent ~= K.ent or yemlik ~= K.yemlik or tip ~= K.tip then
          if ent or yemlik then
               K.ent, K.yemlik, K.tip, K.a, K.x, K.y = ent, yemlik, tip, 0, nil, nil
               K.once = {}
          elseif K.a <= 0 or (K.ent ~= nil and not IsValid(K.ent)) then
               K.ent, K.yemlik, K.tip = nil, nil, nil
          end
     end
     local gorunur = (ent or yemlik) ~= nil
     if V.Sade() then
          K.a = gorunur and 1 or 0
     else
          K.a = math_Clamp(K.a + (gorunur and dt / V.SURE.giris or -dt / V.SURE.cikis), 0, 1)
     end
     if K.a <= 0 or not K.tip then return end
     if K.ent ~= nil and not IsValid(K.ent) then K.a = 0 return end

     -- solarken son konumda kalır (nokta yok); görünürken baş noktasının izdüşümü
     local s = Olcek()
     local yumurtaMi = K.tip == "yumurta"
     local W, H = (yumurtaMi and 420 or 400) * s, 250 * s
     if nokta then
          local sc = nokta:ToScreen()
          if not sc.visible then K.a = 0 return end
          local g = V.Guvenli()
          local tx = sc.x + 36 * s
          if tx + W > ScrW() - g then tx = sc.x - 36 * s - W end
          tx = math_Clamp(tx, g, ScrW() - g - W)
          local ty = math_Clamp(sc.y - H * 0.78, g, ScrH() - g - H)
          if not K.x or V.Sade() then
               K.x, K.y = tx, ty
          else
               K.x, K.y = V.Yaklas(K.x, tx, 22, dt), V.Yaklas(K.y, ty, 22, dt)
          end
     end
     if not K.x then return end
     local a = V.Yumusak(K.a)
     local x0, y0 = math.Round(K.x), math.Round(K.y)

     if K.tip == "yemlik" then
          local i = K.yemlik
          local uzak = not (Y.YemlikErisimde and Y.YemlikErisimde(i))
          local v = YemlikVeri(i, uzak)
          Artislar(TuyKart(x0, y0, s, a, v), v.satir, s)
          return
     end
     local e = K.ent
     local tur = e:TurVeri()
     if not tur then return end
     local uzak = not Y.Erisimde(e)
     if K.tip == "yabani" then
          TuyKart(x0, y0, s, a, YabaniVeri(e, tur, uzak))
     elseif K.tip == "yumurta" then
          local benim = Benim(e)
          local uclar = YumurtaKart(x0, y0, s, a, e, tur, benim, uzak)
          -- ısıtılınca imleçten kor, kuluçka çeyreklerinde madalyondan kıvılcım
          local sc = uclar.sicak
          if sc then
               local o = K.once.sicak
               if o and sc[3] > o + 2 then V.Kivilcim("hud", sc[1], sc[2], R.can, 8, 45, 0.9, 12, s, -math.pi / 2, 1.0) end
               K.once.sicak = sc[3]
          end
          local uo = uclar.oran
          if uo then
               local ceyrek = math_floor(uo[3] * 4)
               if K.once.ceyrek and ceyrek > K.once.ceyrek then V.Kivilcim("hud", uo[1], uo[2], R.altin, 10, 60, 0.8, 14, s) end
               K.once.ceyrek = ceyrek
          end
     else
          local v = YaratikVeri(e, tur, Benim(e), uzak)
          Artislar(TuyKart(x0, y0, s, a, v), v.satir, s)
     end
end)
