-- "addons\\sardongolge\\lua\\sardon_golge\\_sh_1ayar.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Gölge :: ortak — ayarlar, diyalog grupları, hafta anahtarı, oynak fiyat, hançer sayımı, saplama yavaşlatması.
--
-- Akış özeti
--   Gerçeklik Hançeri: Helix eşyası (sayısı "adet" verisinde; Helix eşyaları üst üste yığılmaz) + silah
--   "gerceklikhanceri" (Snatcher sınıfları ve Karanlık Büyücü yükleme silahı; diğerleri eşyadan "Eline Al").
--   Sol tık: öndeki kişiye sapla → bir hançer tükenir, kurbanın o anki görünümü (öğrenci ayarları ya da model)
--   karakterin "gerceklik" verisine yazılır (tek kopya; yenisi eskisini siler). Sağ tık: kılık menüsü (kopyaya
--   dönüş / eski hâl / eski 5 hane kılığı). Kılık: "gerceklikDurum" {aktif, kalan, bekle}; çıkıp girince sürer.
--   Biter: elle, ölüm, Finite / Finite Incantatem, Homenum Revelio (yakındaysa), 60 dk (sonra 5 dk bekleme).
--   Gölge: [sardon] gorev dünya aktörü "golge" (menu = "golge"); E → gizli+geçici görev "golge_karaborsa"
--   (diyalog, dallar, koşullar ve olaylar bu eklentide). Haftalık hak SteamID başına (sardon_golge_hak).
SardonGolge = SardonGolge or {}
local S = SardonGolge

S.ESYA = "gerceklik_hanceri"
S.SILAH = "gerceklikhanceri"
S.GOREV = "golge_karaborsa"
S.AKTOR = "golge"
S.NET = "SardonGolge.Net"

S.OP = { SAPLA = 1, DURUM = 2, ISTEK = 3, SIZI = 4, DUMAN = 5, KAYIT = 6, BILDIR = 7 }
S.OP_BIT = 4
S.ISTEK = { DONUS = 1, GERI = 2, HANE = 3, KAYIT = 4, DURUM = 5 }
S.ISTEK_BIT = 4

S.Ayar = S.Ayar or {}
table.Merge(S.Ayar, {
     -- saplama
     Menzil = 72,               -- birim (göz → hedef)
     KoniCos = 0.6,             -- önde sayılan koni (cos)
     Bekleme = 15,              -- iki saplama arası (sn)
     Hasar = 5,
     Yavaslatma = 0.8,          -- iki taraf bu süre yavaş yürür (sn)
     YavasCarpan = 0.3,
     YasakFraksiyon = { gringotts = true },  -- "Yetkili Görevde"

     -- kılık
     KilikSure = 3600,          -- bir dönüşün süresi (yalnız oyundayken akar)
     YenidenBekleme = 300,      -- süre dolunca yeniden dönüşmek için (sn)
     FiniteMenzil = 400,
     RevelioYaricap = 600,

     -- Gölge
     SnatcherPaket = 5,         -- Snatcher'ın haftalık paketi (hançer)
     SnatcherFiyat = 50,
     SnatcherSinir = 1,         -- haftada kaç paket
     DigerAdet = 1,
     DigerFiyat = 40,           -- taban; haftalık ± FiyatOynama
     FiyatOynama = 0.25,
     DigerSinir = 1,            -- Snatcher olmayan haftada kaç kez
     HediyeSans = 0.15,         -- Snatcher paketine bedava bir hançer
     BakanlikYakalama = 0.5,    -- "Hayır" diyen Bakanlık/Seherbaz çalışanının yakalanma olasılığı
     GezintiSure = 45 * 60,     -- kimse konuşmasa da bu sürede bir yer değiştirir
     KilitZamanAsimi = 240,     -- tek muhatap kilidi en çok (sn)
     GunDonumSaat = 7,          -- TR saati; hafta Pazartesi bu saatte döner
})

-- fraksiyon uniqueID → diyalog grubu (gerisi "diger")
S.Gruplar = {
     snatcher = "snatcher",
     gryffindor = "ogrenci", hufflepuff = "ogrenci", ravenclaw = "ogrenci", slytherin = "ogrenci",
     genelprof = "profesor", hogwartscalisani = "profesor",
     buyubakanligi = "bakanlik", seherbaz = "bakanlik",
     deatheaterr = "karanlik",
}

function S.Fraksiyon(ply)
     local f = IsValid(ply) and ix.faction.indices[ply:Team()]
     return f and f.uniqueID or ""
end

function S.Grup(ply)
     return S.Gruplar[S.Fraksiyon(ply)] or "diger"
end

function S.SnatcherMi(ply)
     return S.Grup(ply) == "snatcher"
end

-- Pazartesi GunDonumSaat (TR, UTC+3) ile dönen hafta
function S.Hafta(t)
     return os.date("!%Y-%W", (t or os.time()) + (3 - S.Ayar.GunDonumSaat) * 3600)
end

-- Snatcher olmayanın fiyatı: haftanın anahtarından tohumlu, o hafta herkese aynı (10'a yuvarlı)
function S.DigerFiyat(hafta)
     local r = ((tonumber(util.CRC("sardon_golge_fiyat_" .. (hafta or S.Hafta()))) or 0) % 10001) / 10000
     local f = S.Ayar.DigerFiyat * (1 + (r * 2 - 1) * S.Ayar.FiyatOynama)
     return math.max(10, math.floor(f / 10 + 0.5) * 10)
end

function S.Fiyat(ply)
     return S.SnatcherMi(ply) and S.Ayar.SnatcherFiyat or S.DigerFiyat()
end

function S.Adet(ply)
     return S.SnatcherMi(ply) and S.Ayar.SnatcherPaket or S.Ayar.DigerAdet
end

-- Envanterdeki (çantalar dahil) hançer sayısı
function S.HancerSay(char)
     local inv = char and char.GetInventory and char:GetInventory()
     if not inv then return 0 end
     local n = 0
     for _, it in pairs(inv:GetItemsByUniqueID(S.ESYA) or {}) do
          n = n + math.max(1, math.floor(tonumber(it:GetData("adet", 1)) or 1))
     end
     return n
end

function S.Sure(sn)
     sn = math.max(0, math.floor(sn or 0))
     if sn >= 3600 then return string.format("%d:%02d:%02d", math.floor(sn / 3600), math.floor(sn % 3600 / 60), sn % 60) end
     return string.format("%d:%02d", math.floor(sn / 60), sn % 60)
end

-- Saplama anında iki taraf kısa süre yavaş yürür (NW2 bitiş anı; iki tarafta aynı, tahmin bozulmaz)
hook.Add("SetupMove", "SardonGolge.Yavas", function(ply, mv)
     if ply:GetNW2Float("GolgeYavas", 0) > CurTime() then
          local c = S.Ayar.YavasCarpan
          mv:SetMaxClientSpeed(mv:GetMaxClientSpeed() * c)
          mv:SetMaxSpeed(mv:GetMaxSpeed() * c)
     end
end)
