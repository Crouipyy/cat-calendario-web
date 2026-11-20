-- "addons\\sardonbuyuagaci\\lua\\sardon_buyuagaci\\_sh_config.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Büyü Ağacı :: ortak kurallar (kademe kilidi, maliyet, düğüm durumu).
-- Dosya adı "_" ile başlıyor ki SardonUtil'in alfabetik yüklemesinde cl_/sv_ dosyalarından önce gelsin.
-- Ağaç içeriği _sh_veri.lua'da.
--
-- Karakter verisi: char:GetData("sardonBuyuAgaci") = {k = kazanılan toplam, h = harcanan, a = {[büyü] = ödenen},
--   t = {[gelişim dalı] = dalda ilk kademenin açıldığı os.time()}}  (t: takvim tabanı, Ayar.bekleme)
-- Helix SetData bu tabloyu sahibine kendiliğinden gönderir; istemci aynı fonksiyonlarla okur.
-- Harcanabilir Büyü Puanı = k - h.
--
-- Büyüler hesap (SteamID) bazında kayıtlı olduğundan bir büyüyü zaten bilen oyuncu için o düğüm
-- ücretsiz "açık" sayılır; ondan sonraki dallar da açılır.
--
-- Ayarlar (BA.Ayar) sunucuda data/sardon_buyuagaci/ayar.json'da durur, herkese gönderilir ve
-- yalnızca süper adminler Shine Admin > "Büyü Ağacı" sayfasından değiştirebilir.

SardonBuyuAgaci = SardonBuyuAgaci or {}
local BA = SardonBuyuAgaci

BA.VeriAnahtari = "sardonBuyuAgaci"

BA.Kademeler = {
     {ad = "Temel Büyüler", kisa = "Temel", roma = "I"},
     {ad = "Basit Büyüler", kisa = "Basit", roma = "II"},
     {ad = "Orta Düzey Büyüler", kisa = "Orta Düzey", roma = "III"},
     {ad = "İleri Düzey Büyüler", kisa = "İleri Düzey", roma = "IV"},
     {ad = "Feci Yorucu Büyüler", kisa = "Feci Yorucu", roma = "V"}
}

-- Karakter Gelişimi ağaçlarındaki sıralar (beceri numaraları, _sh_config_veri.lua düzeni):
-- 1 kök, 2-4 ikinci sıra, 5-7 üçüncü sıra, 8 ustalık
BA.GelisimSiralari = {{1}, {2, 3, 4}, {5, 6, 7}, {8}}

-- Kademe kilidi türleri. deger alanının anlamı türe göre değişir.
BA.KilitTipleri = {
     {id = "acik", ad = "Her zaman açık"},
     {id = "satir", ad = "Gelişim dalında sıra", birim = "sıra", min = 1, max = 4},
     {id = "toplam", ad = "Gelişim dalında toplam kademe", birim = "kademe", min = 1, max = 20},
     {id = "genel", ad = "Tüm gelişimde açılan kademe", birim = "kademe", min = 1, max = 80},
     {id = "seviye", ad = "Karakter seviyesi", birim = "seviye", min = 1, max = 100}
}

function BA.KilitTipi(id)
     for _, t in ipairs(BA.KilitTipleri) do
          if (t.id == id) then return t end
     end
end

BA.Varsayilan = {
     -- 2026-11-13 hesap (~/araclar/buyuagaci_bekleme/puan.py): ders 2 puan, düzenli oyuncu günde 1 ders →
     -- ilk büyü ilk dersten sonra, haftada ~4 büyü, Temel→Feci bir yol 25 puan (~12 ders), 3 haftada ~13 büyü.
     kademeMaliyet = {2, 3, 4, 6, 10},
     -- Takvim tabanı (gün): kademe, bağlı gelişim dalında ilk kademenin açıldığı günden bu kadar sonra açılır.
     -- Çok oynayan da Feci Yorucu'ya 3 haftadan önce ulaşamasın (2026-11-13 kullanıcı).
     bekleme = {0, 0, 7, 14, 21},
     maliyet = {}, -- [büyü adı] = özel puan
     kapali = {}, -- [büyü adı] = true (ağaçta görünür ama açılamaz)
     dersPuan = {}, -- [ders adı] = o dersten gelen puan
     varsayilanDersPuan = 2,
     katilimOrani = 60, -- dersin yüzde kaçında sınıfta bulunmak gerekir
     enAzDersDakika = 10, -- bundan kısa süren derste puan verilmez
     -- 2026-11-13 kullanıcı: her dal Sv1'le 1 bedava kademe veriyor, Basit 2 kademe istesin; ağaç ana dalda
     -- ~3 haftada bitsin. Toplam kademe = bağlı gelişim dalında açılan kademe (8 Kalfa, 14 Usta, 16 dal tamam).
     kilitler = {
          {tip = "acik", deger = 0},
          {tip = "toplam", deger = 2},
          {tip = "toplam", deger = 8},
          {tip = "toplam", deger = 14},
          {tip = "toplam", deger = 16}
     },
     bag = {}, -- [ağaç id] = gelişim kategori id (boşsa ağacın kendi varsayılanı)

     -- Ana / yan dal tavanı: ağacın bağlı olduğu gelişim dalı karakterin ana dalıysa "ana", yan dalıysa
     -- "yan", hiçbiri değilse "diger" kademesine kadar açılabilir (1 = Temel .. 5 = Feci Yorucu).
     -- Kademe kilitlerinin ÜSTÜNE gelir; acik = false yapılınca eski davranışa döner.
     rolTavan = {acik = true, ana = 5, yan = 3, diger = 1},

     -- true: BA.DengeBag'deki ağaçlar tematik dalı yerine oradaki dala bağlanır (dal başına büyü sayısı
     -- yakınlaşır). false: her ağaç kendi "gelisim" alanındaki dala döner.
     dengeBag = true
}

-- Dengeli dağılım (Ayar.dengeBag): [ağaç id] = tematik dalı yerine bağlanacağı gelişim dalı.
-- 9 ağaçlı düzende dallar zaten dengeli olduğu için boş; boşken Shine Admin'deki anahtar da gizlenir.
BA.DengeBag = {}

BA.RolAdlari = {ana = "ana dal", yan = "yan dal", diger = "diğer dal"}

BA.Ayar = BA.Ayar or table.Copy(BA.Varsayilan)

local function Sayi(v, min, max, varsayilan)
     v = math.floor(tonumber(v) or varsayilan)
     return math.Clamp(v, min, max)
end

-- Dışarıdan gelen (dosya / admin) ayar tablosunu güvenli bir kopyaya çevirir
function BA.AyarTemizle(t)
     t = istable(t) and t or {}
     local v = BA.Varsayilan
     local out = {}

     out.kademeMaliyet = {}
     for i = 1, #BA.Kademeler do
          out.kademeMaliyet[i] = Sayi(istable(t.kademeMaliyet) and t.kademeMaliyet[i], 0, 999, v.kademeMaliyet[i])
     end

     out.bekleme = {}
     for i = 1, #BA.Kademeler do
          out.bekleme[i] = Sayi(istable(t.bekleme) and t.bekleme[i], 0, 120, v.bekleme[i])
     end

     out.maliyet = {}
     out.kapali = {}
     for buyu, deger in pairs(istable(t.maliyet) and t.maliyet or {}) do
          if (isstring(buyu) and BA.Dugum(buyu) and tonumber(deger)) then
               out.maliyet[buyu] = Sayi(deger, 0, 999, 1)
          end
     end
     for buyu, deger in pairs(istable(t.kapali) and t.kapali or {}) do
          if (isstring(buyu) and BA.Dugum(buyu) and deger == true) then
               out.kapali[buyu] = true
          end
     end

     out.dersPuan = {}
     for ders, deger in pairs(istable(t.dersPuan) and t.dersPuan or {}) do
          if (isstring(ders) and #ders < 80 and tonumber(deger)) then
               out.dersPuan[ders] = Sayi(deger, 0, 100, 0)
          end
     end

     out.varsayilanDersPuan = Sayi(t.varsayilanDersPuan, 0, 100, v.varsayilanDersPuan)
     out.katilimOrani = Sayi(t.katilimOrani, 0, 100, v.katilimOrani)
     out.enAzDersDakika = Sayi(t.enAzDersDakika, 0, 120, v.enAzDersDakika)

     out.kilitler = {}
     for i = 1, #BA.Kademeler do
          local k = istable(t.kilitler) and t.kilitler[i]
          local tip = istable(k) and BA.KilitTipi(k.tip) or BA.KilitTipi(v.kilitler[i].tip)
          local deger = istable(k) and k.deger or v.kilitler[i].deger
          out.kilitler[i] = {tip = tip.id, deger = tip.min and Sayi(deger, tip.min, tip.max, tip.min) or 0}
     end

     local rt = istable(t.rolTavan) and t.rolTavan or {}
     out.rolTavan = {
          acik = rt.acik == nil and v.rolTavan.acik or rt.acik == true,
          ana = Sayi(rt.ana, 1, #BA.Kademeler, v.rolTavan.ana),
          yan = Sayi(rt.yan, 1, #BA.Kademeler, v.rolTavan.yan),
          diger = Sayi(rt.diger, 1, #BA.Kademeler, v.rolTavan.diger)
     }
     out.dengeBag = t.dengeBag == nil and v.dengeBag or t.dengeBag == true

     out.bag = {}
     for agacId, kat in pairs(istable(t.bag) and t.bag or {}) do
          if (BA.Agac(agacId) and isstring(kat) and #kat < 32) then
               out.bag[agacId] = kat
          end
     end

     return out
end

/*
*   ağaç / düğüm erişimi (harita _sh_veri.lua sonunda BA.HaritaKur ile kurulur)
*/

BA.Agaclar = BA.Agaclar or {}
BA.DugumHaritasi = BA.DugumHaritasi or {}

function BA.Agac(id)
     for i, a in ipairs(BA.Agaclar) do
          if (a.id == id) then return a, i end
     end
end

-- düğüm, ağaç
function BA.Dugum(buyu)
     local d = BA.DugumHaritasi[buyu]
     if (d) then return d, d.agac end
end

-- Aynı daldaki bir alt kademe düğümlerine bağlanır; dalın en altındaysa ağacın temel düğümlerine.
function BA.HaritaKur()
     BA.DugumHaritasi = {}

     for _, agac in ipairs(BA.Agaclar) do
          for _, d in ipairs(agac.dugumler) do
               d.agac = agac
               BA.DugumHaritasi[d.buyu] = d
          end

          for _, d in ipairs(agac.dugumler) do
               if (istable(d.gerekAd)) then
                    d.gerek = d.gerekAd
               else
                    local enIyi = 0
                    for _, o in ipairs(agac.dugumler) do
                         if (o.dal == d.dal and o.kademe < d.kademe and o.kademe > enIyi) then enIyi = o.kademe end
                    end

                    d.gerek = {}
                    for _, o in ipairs(agac.dugumler) do
                         if (enIyi > 0 and o.dal == d.dal and o.kademe == enIyi) then
                              d.gerek[#d.gerek + 1] = o.buyu
                         elseif (enIyi == 0 and d.kademe > 1 and o.kademe == 1) then
                              d.gerek[#d.gerek + 1] = o.buyu
                         end
                    end
               end
          end
     end
end

/*
*   ayar okuma
*/

function BA.Maliyet(buyu)
     local ozel = BA.Ayar.maliyet and BA.Ayar.maliyet[buyu]
     if (ozel) then return ozel end

     local d = BA.Dugum(buyu)
     return d and (BA.Ayar.kademeMaliyet[d.kademe] or 1) or 0
end

function BA.Kapali(buyu)
     return BA.Ayar.kapali and BA.Ayar.kapali[buyu] == true
end

-- Elle bağ verilmemiş ağacın dalı (ayar: BA.Ayar ya da admin taslağı)
function BA.VarsayilanBag(agac, ayar)
     ayar = ayar or BA.Ayar
     return (ayar.dengeBag and BA.DengeBag[agac.id]) or agac.gelisim
end

function BA.GelisimBag(agac, ayar)
     ayar = ayar or BA.Ayar
     return (ayar.bag and ayar.bag[agac.id]) or BA.VarsayilanBag(agac, ayar)
end

-- Ağaçları bağlı oldukları Karakter Gelişimi dalına göre toplar (gelişimdeki dal sırasıyla).
-- {{id = gelişim dalı, ad = "KSKS", agaclar = {ağaç, ...}}, ...}
function BA.Gruplar()
     local G = SardonGelisim
     local out, harita = {}, {}

     local function Grup(id, ad)
          local g = harita[id]
          if (!g) then
               g = {id = id, ad = ad or id, agaclar = {}}
               harita[id] = g
               out[#out + 1] = g
          end
          return g
     end

     for _, k in ipairs(G and G.Kategoriler or {}) do Grup(k.id, k.ad) end
     for _, agac in ipairs(BA.Agaclar) do
          local g = Grup(BA.GelisimBag(agac))
          g.agaclar[#g.agaclar + 1] = agac
     end

     for i = #out, 1, -1 do
          if (#out[i].agaclar == 0) then table.remove(out, i) end
     end
     return out
end

function BA.DersPuani(dersAdi)
     local p = BA.Ayar.dersPuan and BA.Ayar.dersPuan[dersAdi]
     if (p) then return p end
     return BA.Ayar.varsayilanDersPuan or 0
end

/*
*   karakter verisi
*/

function BA.Veri(char)
     local v = char and char:GetData(BA.VeriAnahtari)
     return istable(v) and v or {}
end

function BA.Kazanilan(char)
     return math.max(0, math.floor(tonumber(BA.Veri(char).k) or 0))
end

function BA.Harcanan(char)
     return math.max(0, math.floor(tonumber(BA.Veri(char).h) or 0))
end

function BA.Puan(char)
     if (!char) then return 0 end
     return math.max(0, BA.Kazanilan(char) - BA.Harcanan(char))
end

function BA.Odenen(char, buyu)
     local a = BA.Veri(char).a
     return istable(a) and tonumber(a[buyu]) or nil
end

-- Gelişim dalında ilk kademenin açıldığı an (os.time) ya da nil
function BA.DalBaslangic(char, dal)
     local t = BA.Veri(char).t
     return istable(t) and tonumber(t[dal]) or nil
end

-- "3 gün 4 sa", "5 sa 20 dk", "12 dk"
function BA.SureYaz(sn)
     sn = math.max(0, math.floor(sn))
     local g, s, d = math.floor(sn / 86400), math.floor(sn % 86400 / 3600), math.floor(sn % 3600 / 60)
     if (g > 0) then return g .. " gün" .. (s > 0 and (" " .. s .. " sa") or "") end
     if (s > 0) then return s .. " sa" .. (d > 0 and (" " .. d .. " dk") or "") end
     return math.max(1, d) .. " dk"
end

/*
*   kademe kilidi :: Karakter Gelişimi
*/

local function GelisimKategori(agac)
     local G = SardonGelisim
     if (!G or !G.KategoriBul) then return end
     return G.KategoriBul(BA.GelisimBag(agac))
end

-- Kilidi açan gelişim becerilerinin adları ("Nazik Onarım / Berrak Öz")
local function SiraAdlari(kat, sira)
     local adlar = {}
     for _, no in ipairs(BA.GelisimSiralari[sira] or {}) do
          local b = kat.beceriler[no]
          if (b) then adlar[#adlar + 1] = b.ad end
     end
     return table.concat(adlar, " / ")
end

-- Ağacın bağlı dalının karakterdeki rolü ve o rolün kademe tavanı.
-- rol ("ana" / "yan" / "diger"), tavan (1..5). Tavan kapalıysa ya da gelişim yoksa nil.
function BA.RolTavani(char, agac)
     local t = BA.Ayar.rolTavan
     local G = SardonGelisim
     if (!t or !t.acik or !G or !G.DalRolu or !char) then return end

     local rol = G.DalRolu(char, BA.GelisimBag(agac)) or "diger"
     return rol, t[rol] or #BA.Kademeler
end

-- Takvim tabanı: açık mı, uzun açıklama, birleşik iletide kullanılan kısa açıklama
local function BeklemeAcik(char, agac, kademe)
     local gun = BA.Ayar.bekleme and tonumber(BA.Ayar.bekleme[kademe]) or 0
     if (gun <= 0 or !char) then return true end
     local kat = GelisimKategori(agac)
     if (!kat) then return true end

     local bas = BA.DalBaslangic(char, kat.id)
     -- sunucu: kademesi olup başlangıcı yazılmamış dal (eski kayıt) şimdiden başlar
     if (!bas and SERVER and BA.DalBaslat) then bas = BA.DalBaslat(char, kat.id) end

     local kAd = BA.Kademeler[kademe].ad
     if (!bas) then
          local uzun = kat.ad .. " dalında ilk kademeyi açtıktan " .. gun .. " gün sonra açılır"
          return false, kAd .. ", " .. uzun .. ".", "dalda ilk kademeden " .. gun .. " gün sonra"
     end

     local kalan = bas + gun * 86400 - os.time()
     if (kalan <= 0) then return true end
     local sure = gun .. " gün olmalı (" .. BA.SureYaz(kalan) .. " kaldı)"
     return false, kAd .. " için " .. kat.ad .. " dalına başlayalı " .. sure .. ".", "dala başlayalı " .. sure
end

local KuralAcik

-- açık mı, açıklama (kilitliyse ne gerektiği; açıksa neyle açıldığı)
function BA.KademeAcik(char, agac, kademe)
     local rol, tavan = BA.RolTavani(char, agac)
     if (rol and kademe > tavan) then
          local kat = GelisimKategori(agac)
          local dal = kat and kat.ad or BA.GelisimBag(agac)
          local durum = rol == "diger" and (dal .. " ana ya da yan dalın değil") or (dal .. " senin " .. BA.RolAdlari[rol] .. "ın")
          return false, durum .. "; bu ağaçta en fazla " .. BA.Kademeler[tavan].ad .. " açabilirsin."
     end

     local ok, sebep = KuralAcik(char, agac, kademe)
     local bOk, bSebep, bKisa = BeklemeAcik(char, agac, kademe)
     if (!ok) then
          if (!bOk and bKisa) then sebep = sebep .. "; ayrıca " .. bKisa end
          return false, sebep
     end
     if (!bOk) then return false, bSebep end
     return true, sebep
end

-- Kademe kilidi kuralı (Ayar.kilitler): Karakter Gelişimi / seviye koşulu
KuralAcik = function(char, agac, kademe)
     local kural = BA.Ayar.kilitler and BA.Ayar.kilitler[kademe]
     if (!kural or kural.tip == "acik") then return true, "Her zaman açık" end

     local G = SardonGelisim
     local kAd = BA.Kademeler[kademe].ad

     if (kural.tip == "seviye") then
          local lvl = char and char.GetLVL and math.floor(char:GetLVL() or 0) or 0
          return lvl >= kural.deger, kAd .. " için " .. kural.deger .. ". seviye gerekir"
     end

     -- gelişim eklentisi yoksa kilit uygulanmaz (sistem kilitlenip kalmasın)
     if (!G or !G.Kademe) then return true, "Karakter Gelişimi yüklü değil" end

     if (kural.tip == "genel") then
          local n = char and G.Harcanan(char) or 0
          return n >= kural.deger, kAd .. " için Karakter Gelişimi'nde " .. kural.deger .. " kademe açmalısın (" .. n .. ")"
     end

     local kat = GelisimKategori(agac)
     if (!kat) then return true, "Bağlı gelişim dalı bulunamadı" end

     if (kural.tip == "toplam") then
          local n = char and G.KategoriToplam(char, kat) or 0
          return n >= kural.deger, kAd .. " için Karakter Gelişimi › " .. kat.ad .. " dalında " .. kural.deger .. " kademe gerekir (" .. n .. ")"
     end

     if (kural.tip == "satir") then
          local sira = math.Clamp(kural.deger, 1, #BA.GelisimSiralari)
          if (char) then
               for _, no in ipairs(BA.GelisimSiralari[sira]) do
                    if (G.Kademe(char, kat.id, no) > 0) then return true, kat.ad .. " › " .. SiraAdlari(kat, sira) end
               end
          end
          return false, kAd .. " için Karakter Gelişimi › " .. kat.ad .. " dalında şunlardan birini aç: " .. SiraAdlari(kat, sira)
     end

     return true, ""
end

/*
*   düğüm durumu
*/

-- Büyü bu oyuncuda kayıtlı mı (istemcide yalnızca kendisi için geçerli)
function BA.Biliyor(ply, buyu)
     if (!HpwRewrite or !HpwRewrite.PlayerHasSpell) then return false end
     if (SERVER) then return IsValid(ply) and HpwRewrite:PlayerHasSpell(ply, buyu) or false end
     return HpwRewrite:PlayerHasSpell(nil, buyu) or false
end

function BA.BuyuVar(buyu)
     return HpwRewrite and HpwRewrite.GetSpell and HpwRewrite:GetSpell(buyu) != nil
end

-- Düğüm ilerleme bakımından açık mı (biliniyor ya da parası ödenmiş)
function BA.Acik(ply, char, buyu)
     return BA.Biliyor(ply, buyu) or BA.Odenen(char, buyu) != nil
end

-- Kapalı / sunucuda olmayan büyüler zinciri koparmasın: onların yerine kendi ön koşullarına bakılır
function BA.GerekTamam(ply, char, d, derinlik)
     derinlik = (derinlik or 0) + 1
     if (derinlik > 8 or #d.gerek == 0) then return true end

     for _, ad in ipairs(d.gerek) do
          if (BA.Acik(ply, char, ad)) then return true end

          local o = BA.Dugum(ad)
          if (o and (BA.Kapali(ad) or !BA.BuyuVar(ad)) and BA.GerekTamam(ply, char, o, derinlik)) then
               return true
          end
     end

     return false
end

-- Durum kodları:
--   biliniyor   büyü zaten öğrenilmiş
--   yeniden     parası ödenmiş ama büyü kaybolmuş (ücretsiz geri alınır)
--   yok         bu sunucuda böyle bir büyü yüklü değil
--   kapali      süper admin kapattı
--   kademe      kademe kilidi (Karakter Gelişimi)
--   gerek       önceki düğüm açılmamış
--   puan        puan yetersiz
--   acilabilir  her şey tamam
function BA.Durum(ply, char, buyu)
     local d = BA.Dugum(buyu)
     if (!d) then return "yok", "Bu büyü ağaçta yok." end

     if (BA.Biliyor(ply, buyu)) then return "biliniyor", "Bu büyüyü biliyorsun." end
     if (!BA.BuyuVar(buyu)) then return "yok", "Bu büyü sunucuda yüklü değil." end
     if (BA.Odenen(char, buyu) != nil) then return "yeniden", "Bu büyünün bedelini daha önce ödedin; ücretsiz geri alabilirsin." end
     if (BA.Kapali(buyu)) then return "kapali", "Bu büyü şu anda ağaçtan açılamıyor." end

     local acik, sebep = BA.KademeAcik(char, d.agac, d.kademe)
     if (!acik) then return "kademe", sebep end

     if (!BA.GerekTamam(ply, char, d)) then
          return "gerek", "Önce bu daldaki önceki büyülerden birini aç: " .. table.concat(d.gerek, ", ")
     end

     local maliyet = BA.Maliyet(buyu)
     local puan = BA.Puan(char)
     if (puan < maliyet) then
          return "puan", "Büyü Puanı yetersiz (" .. puan .. " / " .. maliyet .. "). Derslere katılarak puan kazan."
     end

     return "acilabilir", maliyet .. " Büyü Puanı karşılığında açılabilir."
end

-- açık düğüm sayısı, sunucuda var olan düğüm sayısı
function BA.AgacIlerleme(ply, char, agac)
     local acik, toplam = 0, 0
     for _, d in ipairs(agac.dugumler) do
          if (BA.BuyuVar(d.buyu)) then
               toplam = toplam + 1
               if (BA.Acik(ply, char, d.buyu)) then acik = acik + 1 end
          end
     end
     return acik, toplam
end

/*
*   sohbet komutu :: /BuyuPuaniVer <karakter> <miktar>
*/

ix.command.Add("BuyuPuaniVer", {
     description = "Bir karaktere Büyü Puanı verir (eksi değer geri alır).",
     superAdminOnly = true,
     arguments = {ix.type.character, ix.type.number},
     OnRun = function(self, client, target, miktar)
          if (BA.KomutPuanVer) then return BA.KomutPuanVer(client, target, miktar) end
     end
})
