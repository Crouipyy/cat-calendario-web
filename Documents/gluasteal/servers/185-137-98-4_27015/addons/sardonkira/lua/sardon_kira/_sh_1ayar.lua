-- "addons\\sardonkira\\lua\\sardon_kira\\_sh_1ayar.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Kira v2 :: ortak ayarlar (2026-11-12)
-- Kira yaşamı: site (shop.shineroleplay.com) yükleme/ödeme/inceleme -> atölye (bu VPS) LOD + Workshop ->
-- burada: yayındaki modeli açılışta doğrula -> 30 gün ETKİN -> seçilen karaktere bağlı -> bitince 7 gün TOLERANS
-- -> paketten çıkar. Sözleşme: ~/araclar/model_kira/SOZLESME.md

SardonKira = SardonKira or {}
local K = SardonKira

K.ONEK = "models/shinekira/"          -- bütün kira modelleri bu ad alanında
K.GUN = 86400
K.SURE_GUN = 30
K.TOLERANS_GUN = 7
K.BAG_ARALIK = 30 * 86400              -- karakter bağı 30 günde bir değişir
K.SITE_URL = "https://shop.shineroleplay.com"

-- durumlar (GMod tarafı); site durumlarıyla eşlemesi sv_2api'de
K.D = {
     BEKLIYOR = "BEKLIYOR",   -- yayın olayı geldi, model sunucuda doğrulanmadı
     ETKIN = "ETKIN",
     TOLERANS = "TOLERANS",   -- süre bitti, 7 gün içinde uzatılırsa döner
     CIKTI = "CIKTI",         -- tolerans bitti, paketten çıkacak
     IPTAL = "IPTAL",
}

K.DURUM_YAZI = {
     BEKLIYOR = "Yayın sırasında",
     ETKIN = "Etkin",
     TOLERANS = "Süresi doldu",
     CIKTI = "Paketten çıkarıldı",
     IPTAL = "İptal edildi",
}

-- istemci LOD seçimi: tam boyun ekrandaki piksel yüksekliği (öğrenci sisteminin eşikleriyle uyumlu)
K.LOD_ESIK = { 110, 45, 20 }           -- > 110 px LOD0, > 45 LOD1, > 20 LOD2, altı LOD3

function K.KiraModeliMi(mdl)
     return isstring(mdl) and string.sub(string.lower(mdl), 1, #K.ONEK) == K.ONEK
end

function K.KalanGun(bitis)
     return math.max(0, math.ceil(((tonumber(bitis) or 0) - os.time()) / K.GUN))
end

if SERVER then
     util.AddNetworkString("SardonKira")
end

-- ağ işlemleri (tek ileti, 5 bit işlem kodu)
K.OP = {
     LISTE = 1,        -- s->c: kendi kiraların + fiyatlar
     MENU = 2,         -- s->c: menüyü aç
     BAGLA = 3,        -- c->s: kirayı karaktere bağla
     UZAT_SC = 4,      -- c->s: SC ile uzat
     BILDIR = 5,       -- s->c: bildirim
     YONETIM = 6,      -- c->s / s->c: Shine Admin liste
     Y_ISLEM = 7,      -- c->s: yönetim işlemi (uzat/iptal/bag_sifirla/dene)
     DENE_PARCA = 8,   -- s->c: deneme GMA parçası
     DENE_ONAY = 9,    -- c->s: parça alındı
     ISTE = 10,        -- c->s: listeyi iste
     ANLIK = 11,       -- s->c: anlık yayın listesi (restartsız indirilecek Workshop yuvaları)
}

-- anlık yayında model istemciye inene kadar kira sahibi bu modelle çizilir (herkeste var, giyinik)
K.YEDEK_MODEL = "models/player/group01/male_07.mdl"

function K.Yaz(t)
     local s = util.Compress(util.TableToJSON(t or {}) or "{}") or ""
     net.WriteUInt(#s, 32)
     net.WriteData(s, #s)
end

function K.Oku()
     local n = net.ReadUInt(32)
     if n <= 0 or n > 4 * 1024 * 1024 then return {} end
     local s = util.Decompress(net.ReadData(n) or "")
     return s and util.JSONToTable(s) or {}
end
