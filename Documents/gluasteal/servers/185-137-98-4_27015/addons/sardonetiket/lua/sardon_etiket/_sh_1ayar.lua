-- "addons\\sardonetiket\\lua\\sardon_etiket\\_sh_1ayar.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
/*
*   Sardon Etiket — ortak ayar (2026-11-13).
*
*   Discord'da Shine Roleplay sunucusunun etiketini (Server Tag, "SHNE") profilinde takan ve Discord'u oyun
*   hesabına bağlı oyuncu, oyunda AKTİF geçirdiği her dkSaat dakika (60 = saatte 1) için ShineCoin (PulsarStore
*   kredisi) kazanır. Bu, PulsarStore'un herkese verdiği 4 saatlik ödüle (Periodic, 240 dk) EKTİR;
*   TAB oyuncu listesinde adının yanında SHNE rozeti görünür. Ödül OOC'dir, Galleon ekonomisine dokunmaz.
*
*   Etiket, botun REST yoklamasıyla görülür (gateway olayı botlara gelmiyor): üye ucunda user.primary_guild.
*   Ölçüt etiket YAZISI değil, identity_guild_id == sunucu ve identity_enabled == true (başka sunucu da
*   "SHNE" seçebilir). Discord bağı [sardon] giris'in sardon_discord tablosundan okunur (/DiscordBagla).
*
*   Ayarlar data/sardon_etiket/ayar.json ile ezilir; Shine Admin › Etiket sayfasından değiştirilir.
*/
SardonEtiket = SardonEtiket or {}
local E = SardonEtiket

E.Varsayilan = {
     acik = true,          -- sistem açık mı
     scSaat = 1,           -- dolan her ödül dönemi için ShineCoin
     dkSaat = 60,          -- bir ödül dönemi kaç aktif dakika (kullanıcı kararı 11-13: etiketli saatte 1, herkes 4 saatte 1)
     afkDk = 5,            -- son bu kadar dakikada etkinlik yoksa sayılmaz (shinesync AFK'sı 20 dk)
     yoklaDk = 10,         -- çevrimiçi oyuncunun etiketi kaç dakikada bir yoklanır
     hataTolerans = 30,    -- Discord'a ulaşılamazsa son bilinen durum kaç dakika geçerli kalır
     kontrolBekle = 30,    -- "Yeniden kontrol et" düğmesinin bekleme süresi (sn)
     sunucu = "945042002326724649",
}
-- canlı yenilemede yerel kopyalar bayat kalmasın: tablo kimliği korunur
E.Ayar = E.Ayar or {}
for k, v in pairs(E.Varsayilan) do
     if E.Ayar[k] == nil then E.Ayar[k] = v end
end

E.Davet = "https://discord.gg/shinerp"
E.Yetki = "Sardon Etiket Yönetimi"

-- ağ işlemleri (net.WriteUInt 4 bit)
E.OP = {
     DURUM = 1,    -- sunucu → istemci: oyuncunun etiket durumu
     ISTE = 2,     -- istemci → sunucu: sayfa açıldı, durumu gönder
     KONTROL = 3,  -- istemci → sunucu: yeniden yokla
     BAGLA = 4,    -- istemci → sunucu: Kayıt Mührü kod panelini aç
     Y_ISTE = 5,   -- yönetim: veri iste
     Y_VERI = 6,   -- yönetim: veri
     Y_AYAR = 7,   -- yönetim: ayar kaydet
     Y_YOKLA = 8,  -- yönetim: herkesi yeniden yokla
}

E.DurumAd = {
     bekliyor = "Yoklanıyor",
     kapali = "Sistem kapalı",
     bagli_degil = "Discord bağlı değil",
     sunucuda_degil = "Discord sunucusunda değil",
     etiket_yok = "Etiket takılı değil",
     etiket = "SHNE takılı",
     cakisma = "Discord başka hesaba da bağlı",
     hata = "Discord'a ulaşılamadı",
}

-- "her 4 saatte" / "her saat" / "her 90 dakikada"
function E.AralikMetni(dk)
     dk = math.floor(tonumber(dk) or E.Ayar.dkSaat)
     if dk % 60 == 0 then
          local s = dk / 60
          return s == 1 and "her saat" or ("her " .. s .. " saatte")
     end
     return "her " .. dk .. " dakikada"
end

-- 72 → "1 sa 12 dk", 240 → "4 sa"
function E.SureMetni(dk)
     dk = math.max(0, math.floor(tonumber(dk) or 0))
     local s, d = math.floor(dk / 60), dk % 60
     if s > 0 and d > 0 then return s .. " sa " .. d .. " dk" end
     if s > 0 then return s .. " sa" end
     return d .. " dk"
end

function E.Yonetici(ply)
     if not IsValid(ply) then return false end
     if ply:IsSuperAdmin() then return true end
     if CAMI and CAMI.PlayerHasAccess then
          local ok, sonuc = pcall(CAMI.PlayerHasAccess, ply, E.Yetki, nil)
          if ok and sonuc then return true end
     end
     return false
end

if CAMI and CAMI.RegisterPrivilege then
     CAMI.RegisterPrivilege({ Name = E.Yetki, MinAccess = "superadmin", Description = "Discord etiketi (SHNE) ödülünün ayarlarını ve oyuncu durumlarını yönetir." })
end
