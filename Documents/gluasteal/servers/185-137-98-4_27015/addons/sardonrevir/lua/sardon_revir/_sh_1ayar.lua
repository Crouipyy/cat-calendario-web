-- "addons\\sardonrevir\\lua\\sardon_revir\\_sh_1ayar.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Revir :: ayarlar, harita yerleşimi, ortak kurallar.
-- Dosya adı "_" ile başlıyor: SardonUtil alfabetik yüklemede cl_/sv_ dosyalarından önce gelsin.
--
-- Veri yerleri:
--   sqlite sardon_revir_karakter (charid PK): toplam deneyim, dal puanı birikimi, ustalık, geçmiş
--   sqlite sardon_revir_log
--   data/sardon_revir/ayar.json, data/sardon_revir/harita_<map>.json (yatak / Pomfrey / defter / dolap)
-- Şifa dal puanı Karakter Gelişimi verisine yazılır (SardonGelisim.DalPuanEkle, yalnız Şifa'ya harcanır).

SardonRevir = SardonRevir or {}
local R = SardonRevir

R.Kat = "sifa" -- bağlı Karakter Gelişimi dalı

-- Şifa dalı becerileri (Karakter Gelişimi sırası) ve revirdeki karşılıkları
R.BECERI = {
     IZLER = 1,       -- Yaşamın İzleri: zorluk 3 vakalar
     NAZIK = 2,       -- Nazik Onarım: Onarım vakalarında çizim eşiği −3 / kademe
     BERRAK = 3,      -- Berrak Öz: tarama bir muayene bulgusunu da gösterir; 2. kademe Arındırma eşiği −3
     KORUYUCU = 4,    -- Koruyucu Dokunuş: her hastada ilk (2. kademede ilk iki) yanlış tedavi etkisiz
     DERIN = 5,       -- Derin İyileşme: zorluk 4 vakalar
     SAFLIK = 6,      -- Saflık Çemberi: nöbete 4. (acil) hasta
     KALKAN = 7,      -- Yaşam Kalkanı: Pomfrey bir yanlış daha bekler
     USTALIK = 8      -- Şifa Ustalığı: bilinmeyen büyünün tutunma şansı +15 / kademe
}

R.VarsayilanAyar = {
     acik = true,
     hastaSayisi = 3,
     eszamanli = 2,         -- aynı anda nöbet tutabilecek gönüllü
     gunluk = 1,            -- karakter başına günlük nöbet
     sifirlamaSaat = 7,     -- günlük hak bu saatte yenilenir (Şans sistemiyle aynı)
     esik = 72,             -- rün eşiği (%)
     tutunma = 35,          -- bilinmeyen büyünün taban tutunma şansı (%)
     garanti = 3,           -- bilinmeyen büyü en geç bu kadar iyi çizimde tutar
     yanlisSiniri = 2,      -- bu kadar yanlış tedavide Pomfrey devralır
     deneyimTaban = 30,     -- zorluk başına deneyim
     dalPuaniEsik = 250,    -- bu kadar deneyim = 1 Şifa puanı
     pomfreyBonus = 25,     -- revirde Poppy Pomfrey (oyuncu) varken deneyim +%
     onur = 2,              -- iyileştirilen hasta başına Onur
     nobetDakika = 30,      -- nöbet zaman aşımı
     uzaklasma = 120,       -- revirden bu kadar sn uzak kalan gönüllünün nöbeti biter
     ustalik = {1, 4, 10, 22, 40},  -- uygulama sayısı: Tanışık, Öğrenildi, Yetkin, Usta, Üstat
     ogrenmeKademe = 2,     -- bu ustalık kademesine gelince bilinmeyen büyü verilir
     disBonus = {0, 3, 6, 10, 15}   -- ustalık kademesine göre revir dışında şifa +% (en çok 15)
}

R.Ayar = R.Ayar or table.Copy(R.VarsayilanAyar)

local function Sayi(v, d, mn, mx)
     v = tonumber(v)
     if (!v) then return d end
     return math.Clamp(v, mn, mx)
end

function R.AyarTemizle(t)
     t = istable(t) and t or {}
     local V = R.VarsayilanAyar
     local o = {}
     o.acik = t.acik == nil and V.acik or t.acik == true
     o.hastaSayisi = math.floor(Sayi(t.hastaSayisi, V.hastaSayisi, 1, 3))
     o.eszamanli = math.floor(Sayi(t.eszamanli, V.eszamanli, 1, 6))
     o.gunluk = math.floor(Sayi(t.gunluk, V.gunluk, 1, 10))
     o.sifirlamaSaat = math.floor(Sayi(t.sifirlamaSaat, V.sifirlamaSaat, 0, 23))
     o.esik = math.floor(Sayi(t.esik, V.esik, 40, 95))
     o.tutunma = math.floor(Sayi(t.tutunma, V.tutunma, 0, 100))
     o.garanti = math.floor(Sayi(t.garanti, V.garanti, 1, 10))
     o.yanlisSiniri = math.floor(Sayi(t.yanlisSiniri, V.yanlisSiniri, 1, 6))
     o.deneyimTaban = math.floor(Sayi(t.deneyimTaban, V.deneyimTaban, 1, 500))
     o.dalPuaniEsik = math.floor(Sayi(t.dalPuaniEsik, V.dalPuaniEsik, 10, 10000))
     o.pomfreyBonus = math.floor(Sayi(t.pomfreyBonus, V.pomfreyBonus, 0, 200))
     o.onur = math.floor(Sayi(t.onur, V.onur, 0, 50))
     o.nobetDakika = math.floor(Sayi(t.nobetDakika, V.nobetDakika, 5, 120))
     o.uzaklasma = math.floor(Sayi(t.uzaklasma, V.uzaklasma, 20, 900))
     o.ogrenmeKademe = math.floor(Sayi(t.ogrenmeKademe, V.ogrenmeKademe, 1, 5))

     o.ustalik = {}
     local onceki = 0
     for i = 1, 5 do
          local d = math.floor(Sayi(istable(t.ustalik) and t.ustalik[i], V.ustalik[i], 1, 1000))
          d = math.max(d, onceki + 1)
          o.ustalik[i] = d
          onceki = d
     end
     o.disBonus = {}
     for i = 1, 5 do
          o.disBonus[i] = math.floor(Sayi(istable(t.disBonus) and t.disBonus[i], V.disBonus[i], 0, 15))
     end
     return o
end

R.Ayar = R.AyarTemizle(R.Ayar)

--[[
*   gün :: günlük hak sifirlamaSaat'te yenilenir
]]

function R.Gun(t)
     return os.date("%Y-%m-%d", (t or os.time()) - R.Ayar.sifirlamaSaat * 3600)
end

function R.SonrakiSifirlama()
     local simdi = os.time()
     local d = os.date("*t", simdi)
     d.hour, d.min, d.sec = R.Ayar.sifirlamaSaat, 0, 0
     local t = os.time(d)
     if (t <= simdi) then t = t + 86400 end
     return t - simdi
end

--[[
*   yollar, kalıntılar, ustalık, unvan
]]

R.Yollar = {
     onarim = {ad = "Onarım", renk = Color(214, 120, 104), aciklama = "Yaralar, kırıklar, yanıklar"},
     arindirma = {ad = "Arındırma", renk = Color(132, 196, 120), aciklama = "Zehirler, uğursuzluklar, hastalıklar"},
     koruma = {ad = "Koruyucu Şifa", renk = Color(132, 170, 226), aciklama = "Bilinç, ruh ve soğuk"}
}
R.YolSira = {"onarim", "arindirma", "koruma"}

-- Asayla taramada hastanın çevresinde beliren kalıntı rengi
R.Kalintilar = {
     kirmizi = {ad = "Kızıl kalıntı", renk = Color(232, 84, 72), anlam = "bedensel yara"},
     yesil = {ad = "Yeşil kalıntı", renk = Color(108, 220, 96), anlam = "zehir, bitki ya da iksir"},
     mor = {ad = "Mor kalıntı", renk = Color(170, 96, 232), anlam = "lanet, uğursuzluk ya da kara büyü"},
     mavi = {ad = "Mavi kalıntı", renk = Color(96, 170, 255), anlam = "bilinç, ruh, soğuk ya da cisimlenme"},
     turuncu = {ad = "Turuncu kalıntı", renk = Color(255, 160, 64), anlam = "ateşli büyülü hastalık"}
}

R.UstalikAdlari = {[0] = "Yabancı", "Tanışık", "Öğrenildi", "Yetkin", "Usta", "Üstat"}
R.UstalikRenk = {
     [0] = Color(127, 137, 120), Color(171, 169, 147), Color(174, 196, 140),
     Color(140, 200, 220), Color(222, 192, 120), Color(255, 226, 150)
}

-- uygulama sayısı → ustalık kademesi (0..5)
function R.UstalikKademe(sayi)
     sayi = tonumber(sayi) or 0
     local k = 0
     for i, esik in ipairs(R.Ayar.ustalik) do
          if (sayi >= esik) then k = i end
     end
     return k
end

-- bir sonraki kademe eşiği (yoksa nil)
function R.UstalikSonraki(sayi)
     local k = R.UstalikKademe(sayi)
     return R.Ayar.ustalik[k + 1]
end

R.Unvanlar = {
     {0, "Gönüllü"},
     {15, "Revir Yardımcısı"},
     {50, "Şifacı Çırağı"},
     {120, "Şifacı"},
     {250, "Baş Şifacı"}
}

function R.Unvan(iyilestirilen)
     iyilestirilen = tonumber(iyilestirilen) or 0
     local ad, no, sonraki = R.Unvanlar[1][2], 1, R.Unvanlar[2] and R.Unvanlar[2][1]
     for i, u in ipairs(R.Unvanlar) do
          if (iyilestirilen >= u[1]) then
               ad, no = u[2], i
               sonraki = R.Unvanlar[i + 1] and R.Unvanlar[i + 1][1]
          end
     end
     return ad, no, sonraki
end

--[[
*   yardımcılar
]]

-- tohumlu rastgele (sunucu ile istemci aynı diziyi üretir)
function R.Rastgele(tohum)
     local s = math.floor(math.abs(tonumber(tohum) or 1)) % 2147483647
     if (s <= 0) then s = s + 2147483646 end
     return function(a, b)
          s = (s * 16807) % 2147483647
          local f = (s - 1) / 2147483646
          if (a and b) then return a + math.floor(f * (b - a + 1)) end
          if (a) then return 1 + math.floor(f * a) end
          return f
     end
end

function R.Sec(liste, rnd)
     if (!istable(liste) or #liste == 0) then return nil end
     local f = rnd and rnd() or math.random()
     return liste[1 + math.floor(f * #liste) % #liste]
end

-- Karakter Gelişimi Şifa dalındaki beceri kademesi
function R.Beceri(char, no)
     local G = SardonGelisim
     if (!char or !G or !G.Kademe) then return 0 end
     return G.Kademe(char, R.Kat, no)
end

-- Büyünün kademesi (Büyü Ağacı'ndaki yeri; ağaçta değilse revirin kendi tablosu) ve ağacı
R.EkKademe = {["Ferula"] = 2, ["Finite Incantatem"] = 2}

-- (ağaç = Büyü Ağacı'nın ağaç tablosu; BA.KademeAcik bunu ister)
function R.BuyuKademe(buyu)
     local BA = SardonBuyuAgaci
     local d = BA and BA.Dugum and BA.Dugum(buyu)
     if (d) then return d.kademe, d.agac end
     return R.EkKademe[buyu] or 2, BA and BA.Agac and BA.Agac("sifa") or nil
end

--[[
*   harita yerleşimi :: yatak = şilte üstünde baş ve ayak noktası (+ başucunda durulacak yer)
*   rp_sh2 değerleri BSP statik proplarından ve zemin izinden ölçüldü (2026-10-31).
]]

R.HaritaVarsayilan = {
     rp_sh2 = {
          kutu = {min = Vector(-8995, -5860, -10150), max = Vector(-8335, -4095, -9940)},
          giris = Vector(-8680, -5581, -10137),
          pomfrey = {pos = Vector(-8650, -4178, -10138), yaw = -90},
          defter = {pos = Vector(-8645, -4243, -10096), yaw = 90}, -- masanın sağ ön boşluğu; yaw = okuyanın baktığı yön (kuzey)
          dolap = {pos = Vector(-8658, -4146, -10066), yaw = -90},
          yataklar = {
               {bas = Vector(-8361, -4249, -10108), ayak = Vector(-8433, -4249, -10108), yan = Vector(-8402, -4190, -10138)},
               {bas = Vector(-8361, -4467, -10108), ayak = Vector(-8433, -4467, -10108), yan = Vector(-8398, -4416, -10138)},
               {bas = Vector(-8361, -4679, -10108), ayak = Vector(-8433, -4679, -10108), yan = Vector(-8396, -4628, -10138)},
               {bas = Vector(-8973, -4256, -10111), ayak = Vector(-8897, -4256, -10111), yan = Vector(-8930, -4200, -10138)},
               {bas = Vector(-8973, -4476, -10111), ayak = Vector(-8897, -4476, -10111), yan = Vector(-8927, -4418, -10138)},
               {bas = Vector(-8973, -4693, -10111), ayak = Vector(-8897, -4693, -10111), yan = Vector(-8922, -4637, -10138)}
          }
     }
}

R.Harita = R.Harita or nil

local function V(t)
     if (isvector(t)) then return Vector(t) end
     if (istable(t)) then return Vector(tonumber(t[1] or t.x) or 0, tonumber(t[2] or t.y) or 0, tonumber(t[3] or t.z) or 0) end
end

-- JSON'dan gelen (ya da varsayılan) harita tablosunu Vector'lere çevirir
function R.HaritaCoz(t)
     if (!istable(t)) then return nil end
     local o = {yataklar = {}}
     if (istable(t.kutu)) then o.kutu = {min = V(t.kutu.min), max = V(t.kutu.max)} end
     o.giris = V(t.giris)
     for _, ad in ipairs({"pomfrey", "defter", "dolap"}) do
          if (istable(t[ad])) then o[ad] = {pos = V(t[ad].pos), yaw = tonumber(t[ad].yaw) or 0} end
     end
     for i, y in ipairs(istable(t.yataklar) and t.yataklar or {}) do
          local bas, ayak, yan = V(y.bas), V(y.ayak), V(y.yan)
          if (bas and ayak and yan) then
               o.yataklar[#o.yataklar + 1] = {no = #o.yataklar + 1, bas = bas, ayak = ayak, yan = yan, kapali = y.kapali == true}
          end
     end
     if (!o.kutu or !o.giris or !o.pomfrey or !o.defter or !o.dolap or #o.yataklar == 0) then return nil end
     return o
end

-- Vector'leri JSON'a yazılabilir tabloya çevirir
function R.HaritaYaz(h)
     local function T(v) return {math.Round(v.x, 1), math.Round(v.y, 1), math.Round(v.z, 1)} end
     local o = {kutu = {min = T(h.kutu.min), max = T(h.kutu.max)}, giris = T(h.giris), yataklar = {}}
     for _, ad in ipairs({"pomfrey", "defter", "dolap"}) do o[ad] = {pos = T(h[ad].pos), yaw = math.Round(h[ad].yaw, 1)} end
     for _, y in ipairs(h.yataklar) do
          o.yataklar[#o.yataklar + 1] = {bas = T(y.bas), ayak = T(y.ayak), yan = T(y.yan), kapali = y.kapali or nil}
     end
     return o
end

function R.HaritaVarsayilanKopya()
     local v = R.HaritaVarsayilan[game.GetMap()]
     return v and R.HaritaCoz(v) or nil
end

function R.RevirdeMi(pos)
     local h = R.Harita
     return h != nil and isvector(pos) and pos:WithinAABox(h.kutu.min, h.kutu.max)
end

function R.Yatak(no)
     return R.Harita and R.Harita.yataklar[no]
end

-- Yatakta yatış / oturuş yeri: yön = ayaktan başa
function R.YatakYon(y)
     local d = y.bas - y.ayak
     d.z = 0
     return d:GetNormalized(), d:Angle().y
end

-- hastanın başının üstü (konuşma balonu, tarama halkası, çizim düzlemi hedefi)
function R.YatakOrta(y)
     return (y.bas + y.ayak) / 2
end

-- Poppy Pomfrey sınıfında bir oyuncu revirde mi (varsa NPC Pomfrey çekilir, deneyim bonusu)
function R.PomfreyOyuncu()
     if (!R.Harita) then return nil end
     for _, p in player.Iterator() do
          if (p:Alive() and R.RevirdeMi(p:GetPos())) then
               local char = p.GetCharacter and p:GetCharacter()
               local sinif = char and char.GetClass and char:GetClass()
               local veri = sinif and ix and ix.class and ix.class.list[sinif]
               if (veri and veri.name == "Poppy Pomfrey") then return p end
          end
     end
end

-- Bu dosya her iki tarafta: istemci harita verisini sunucudan alır (sv_1veri)
if (CLIENT) then
     R.Harita = R.Harita or R.HaritaVarsayilanKopya()
end
