-- "addons\\sardongorev\\lua\\sardon_gorev\\_sh_1cekirdek.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
/*
*   Sardon Görev — görev sistemi
*
*   AKIŞ ÖZETİ
*   Görev tanımı (data/sardon_gorev/gorevler/<id>.json) = meta + koşullar + aktörler + adımlar.
*   Her adım:  giriş eylemleri (sırayla, bekleyebilir)  →  hedefler (hepsi / biri)
*              →  çıkış eylemleri  →  sonraki adım (ya da dallanma / bitiş).
*   Adım sürerken "replikler" (aktörün kendiliğinden söylediği sözler) tetiklere göre çalar.
*
*   Örnek (görevin oyuncudaki kopyası) sunucuda yaşar; adım başında sqlite'a kontrol noktası
*   yazılır, oyuncu çıkıp girince aynı adımdan, aktörler kaldıkları yerden sürer.
*
*   Aktörler sunucuda simüle edilir (konum, yol, rehberlik, bakış), istemcide ClientsideModel
*   olarak çizilir: yol + hız + başlangıç zamanı gönderilir, istemci aynı hareketi kendisi yürütür.
*   Görünürlük: "kisisel" yalnız görevin sahibi, "cevre" yakındaki herkes.
*
*   Sesler: data/sardon_gorev/sesler/<yol> (mp3/ogg/wav). Sunucu parça parça gönderir, istemci
*   data/sardon_gorev/onbellek/<crc>.<uzantı> olarak saklar, 3B kanalla aktörün ağzından çalar.
*   Dosya yoksa altyazı tek başına oynar (süre metinden hesaplanır).
*
*   Görev türleri: ana, yan, günlük (her gün 07:00'de seçilir), karşılaşma (RDR'deki gibi
*   dünyada belli yer/saat/koşulda rastgele çıkar), etkinlik.
*   Başlatma: otomatik (koşul sağlanınca), görev veren dünya aktörü, olay, elle.
*
*   Yerler (data/sardon_gorev/yerler/<harita>.json) görevlerden ayrıdır: görev harita
*   bağımsızdır, yer adlarıyla konuşur. Araç (toolgun) ve editörden yerleştirilir.
*
*   Yükleme sırası: _sh_* → cl_* → sv_* (alfabetik). Dosya adlarında başka bir realm'in
*   öneki (sv_/sh_/cl_) geçmemeli: SardonUtil yolun tamamında arar.
*/
SardonGorev = SardonGorev or {}
local G = SardonGorev

G.Ayar = G.Ayar or {}
local A = G.Ayar

-- Canlı yenilemede tablo yerinde güncellenir (dosyalar `local A = G.Ayar` tutuyor)
local AYAR = {
     Tik = 0.1,                 -- sıra işleyici
     KontrolAraligi = 0.25,     -- yoklanan hedefler
     CevreMesafe = 2600,        -- "cevre" aktörleri bu mesafedeki oyunculara gider
     CevreCikis = 3000,         -- bu mesafeyi aşınca silinir
     KonusMesafe = 140,         -- E ile konuşma
     GunlukSayi = 3,            -- günde atanan günlük görev
     GunDonumSaat = 7,          -- TR saati
     KarsilasmaAraligi = 8,     -- yönetmen turu (sn)
     KarsilasmaKorunma = 180,   -- girişten sonra bu süre karşılaşma çıkmaz
     KarsilasmaArasi = 240,     -- oyuncu başı iki karşılaşma arası en az
     AktifMaks = 12,            -- oyuncu başı eşzamanlı görev
     SesParca = 15000,          -- bayt
     SesButce = 4,              -- 0.1 sn'de toplam parça
     SesMaks = 3 * 1024 * 1024, -- tek dosya
     AltyaziHiz = 0.062,        -- ses yoksa harf başı süre
     AltyaziEk = 1.1,
     YuruHiz = 78,
     KosHiz = 215,
     RehberBekle = 380,         -- oyuncu bu kadar geride kalınca rehber durur
     RehberDevam = 230,         -- bu kadar yaklaşınca yürür
}
for k, v in pairs(AYAR) do A[k] = v end

G.Turler = {
     { id = "ana", ad = "Misión principal", kisa = "PRINCIPAL", renk = Color(223, 193, 128) },
     { id = "yan", ad = "Misión secundaria", kisa = "SECUNDARIA", renk = Color(168, 196, 214) },
     { id = "gunluk", ad = "Misión diaria", kisa = "DIARIO", renk = Color(160, 200, 150) },
     { id = "karsilasma", ad = "Encuentro", kisa = "ENCUENTRO", renk = Color(214, 150, 120) },
     { id = "etkinlik", ad = "Evento", kisa = "EVENTO", renk = Color(196, 160, 220) },
}
G.TurMap = {}
for i, t in ipairs(G.Turler) do t.sira = i G.TurMap[t.id] = t end

function G.Tur(id) return G.TurMap[id] or G.TurMap.yan end

/*
*   Yetki
*/
G.Yetki = "Sardon - Editor de misiones"

if CAMI and CAMI.RegisterPrivilege then
     CAMI.RegisterPrivilege({
          Name = G.Yetki,
          MinAccess = "superadmin",
          Description = "Abre el editor de misiones; edita misiones, lugares y actores; permite probar misiones."
     })
end

function G.Editor(ply)
     if not IsValid(ply) then return false end
     if ply:IsSuperAdmin() then return true end
     if CAMI and CAMI.PlayerHasAccess then
          local ok, sonuc = pcall(CAMI.PlayerHasAccess, ply, G.Yetki, nil)
          if ok and sonuc then return true end
     end
     return false
end

/*
*   Yardımcılar
*/
local BUYUK = { ["i"] = "İ", ["ı"] = "I", ["ç"] = "Ç", ["ş"] = "Ş", ["ğ"] = "Ğ", ["ü"] = "Ü", ["ö"] = "Ö" }
local KUCUK = { ["I"] = "ı", ["İ"] = "i", ["Ç"] = "ç", ["Ş"] = "ş", ["Ğ"] = "ğ", ["Ü"] = "ü", ["Ö"] = "ö" }

function G.Buyuk(s)
     s = string.gsub(tostring(s or ""), "[%z\1-\127\194-\244][\128-\191]*", function(c) return BUYUK[c] or c end)
     return string.upper(s)
end

function G.Kucuk(s)
     s = string.gsub(tostring(s or ""), "[%z\1-\127\194-\244][\128-\191]*", function(c) return KUCUK[c] or c end)
     return string.lower(s)
end

local TR = { ["ç"] = "c", ["ğ"] = "g", ["ı"] = "i", ["ö"] = "o", ["ş"] = "s", ["ü"] = "u",
     ["Ç"] = "c", ["Ğ"] = "g", ["İ"] = "i", ["Ö"] = "o", ["Ş"] = "s", ["Ü"] = "u" }

-- Görev / adım / yer kimliği: küçük harf, rakam, alt çizgi
function G.Kimlik(s)
     s = string.gsub(tostring(s or ""), "[\195\196\197][\128-\191]", TR)
     s = string.lower(s)
     s = string.gsub(s, "[^%w_]", "_")
     s = string.gsub(s, "_+", "_")
     return string.sub(s, 1, 40)
end

-- Ses yolu: alt klasör + dosya; ".." ve mutlak yol yok
function G.SesYolu(s)
     s = string.Trim(tostring(s or ""))
     s = string.gsub(s, "\\", "/")
     if s == "" or string.find(s, "..", 1, true) or string.sub(s, 1, 1) == "/" then return nil end
     if not string.match(s, "^[%w_%-/%.]+$") then return nil end
     local uzanti = string.lower(string.GetExtensionFromFilename(s) or "")
     if uzanti ~= "mp3" and uzanti ~= "ogg" and uzanti ~= "wav" then return nil end
     return string.lower(s)
end

function G.Kopya(t)
     if not istable(t) then return t end
     return table.Copy(t)
end

-- Yüzeysel kopya: dolaşırken tablo değişebilecekse (table.Copy DERİN kopyalar, örnek nesneleri kopyalanır!)
function G.Sig(t)
     local k = {}
     for a, b in pairs(t or {}) do k[a] = b end
     return k
end

function G.Galleon(n)
     return string.Comma(math.floor(tonumber(n) or 0)) .. " Galleon"
end

-- UTF-8 güvenli kesme
function G.Kes(s, n)
     s = tostring(s or "")
     local son = utf8.offset(s, n + 1)
     if not son then return s end
     return string.sub(s, 1, son - 1)
end

function G.Kisalt(s, n)
     s = tostring(s or "")
     local uz = utf8.len(s)
     if uz and uz > n then return G.Kes(s, n - 1) .. "…" end
     return s
end

-- Metinde {oyuncu}, {hane}, {d:degisken} yer tutucuları
function G.Doldur(metin, ply, o)
     metin = tostring(metin or "")
     if not string.find(metin, "{", 1, true) then return metin end

     return (string.gsub(metin, "{([%w_:]+)}", function(k)
          if k == "oyuncu" then
               return IsValid(ply) and ply:Nick() or "desconocido"
          elseif k == "ad" then
               local ad = IsValid(ply) and ply:Nick() or ""
               return string.match(ad, "^(%S+)") or ad
          elseif k == "hane" then
               local char = IsValid(ply) and ply.GetCharacter and ply:GetCharacter()
               local h = char and char.GetHouse and char:GetHouse()
               return G.HaneAdlari[h or 0] or "hane"
          elseif string.sub(k, 1, 2) == "d:" and o and o.deg then
               local v = o.deg[string.sub(k, 3)]
               return v ~= nil and tostring(v) or ""
          end
     end))
end

G.HaneAdlari = { [1] = "Gryffindor", [2] = "Ravenclaw", [3] = "Slytherin", [4] = "Hufflepuff" }

-- Ses dosyası yoksa altyazı süresi
function G.MetinSure(metin)
     local n = utf8.len(tostring(metin or "")) or #tostring(metin or "")
     return math.Clamp(n * A.AltyaziHiz + A.AltyaziEk, 1.4, 14)
end

/*
*   Ağ: sıkıştırılmış tablo
*/
function G.YazTablo(t)
     local s = util.Compress(util.TableToJSON(t or {}) or "{}") or ""
     net.WriteUInt(#s, 32)
     if #s > 0 then net.WriteData(s, #s) end
end

function G.OkuTablo()
     local n = net.ReadUInt(32)
     if n <= 0 or n > 4 * 1024 * 1024 then return {} end
     local s = net.ReadData(n)
     local json = s and util.Decompress(s)
     return json and util.JSONToTable(json) or {}
end

-- İstemci → sunucu istek kodları (SardonGorev.Istek)
G.ISTEK = {
     KONUS = 1,      -- aktör no
     SECIM = 2,      -- seçenek
     ATLA = 3,       -- satır / sahne atla
     TAKIP = 4,      -- günlükte takip et
     BIRAK = 5,      -- görevi bırak
     SES = 6,        -- ses dosyası iste
     DURUM = 7,      -- durumu yeniden gönder
     KABUL = 8,      -- görev veren teklifi: kabul
     RED = 9,        -- teklif reddi
     TOPLA = 10,     -- görev nesnesi topla
     ETKILESIM = 11, -- E basılı tutma bitti
     HAZIR = 12,     -- istemci yüklendi
}

-- Aktör paket kodları (SardonGorev.Aktor)
G.AKTOR = {
     OLUSTUR = 1, SIL = 2, HAREKET = 3, DUR = 4, BAK = 5, ANIM = 6, KONUS = 7, HARE = 8, OZELLIK = 9, KONUM = 10,
     BINIS = 11,
}

-- Sahne/arayüz paket kodları (SardonGorev.Sahne)
G.SAHNE = {
     KAMERA = 1, KAMERA_BITIR = 2, KARART = 3, BASLIK = 4, MUZIK = 5, MUZIK_DUR = 6, EFEKT = 7,
     SINEMA = 8, SERIT = 9, PARCACIK = 10, SES = 11, NESNE = 12, NESNE_SIL = 13, BILDIRIM = 14, KILIT = 15,
}

/*
*   Hareket kilidi (diyalog / sinematik sırasında). Paylaşılan: tahmin iki tarafta aynı.
*/
local KILIT_TUS = bit.bor(IN_ATTACK, IN_ATTACK2, IN_JUMP, IN_DUCK, IN_RELOAD, IN_FORWARD, IN_BACK, IN_MOVELEFT, IN_MOVERIGHT, IN_SPEED, IN_WALK)

hook.Add("StartCommand", "SardonGorev.Kilit", function(ply, cmd)
     if not ply:GetNW2Bool("SardonGorevKilit") then return end
     cmd:RemoveKey(KILIT_TUS)
     cmd:SetForwardMove(0)
     cmd:SetSideMove(0)
     cmd:SetUpMove(0)
end)

hook.Add("SetupMove", "SardonGorev.Kilit", function(ply, mv)
     if not ply:GetNW2Bool("SardonGorevKilit") then return end
     mv:SetForwardSpeed(0)
     mv:SetSideSpeed(0)
     mv:SetUpSpeed(0)
     local v = mv:GetVelocity()
     mv:SetVelocity(Vector(0, 0, math.min(v.z, 0)))
end)
