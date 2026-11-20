-- "addons\\sardonrepsus\\lua\\sardon_repsus\\_sh_1ayar.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
--[[
     Sardon Repsus :: ortak ayarlar.
     Ayarlar data/sardon_repsus/ayar.json'da (Shine Admin › Repsus sayfasından değişir).
]]

SardonRepsus = SardonRepsus or {}
local R = SardonRepsus

R.Varsayilan = {
     acik = true,          -- Repsus servisi
     herkes = false,       -- kapalıyken Repsus'u yalnız aç oyuncu görür
     esik = 25,            -- açlık ya da susuzluk bu değere inince gelir (0-100)
     uykuEsik = 25,        -- uyku (needs/comfort "sleep_need") bu değere inince kahve getirir
     bekleme = 45,         -- aynı karaktere iki ziyaret arası (dakika)
     aclikSaat = 6,        -- açlık 100'den 0'a (saat, duran oyuncu)
     susuzlukSaat = 5,     -- susuzluk 100'den 0'a (saat, duran oyuncu)
     hareket = 1.25,       -- son dakikada yol alan oyuncuda tüketim çarpanı
}

-- canlı yenilemede yerel kopyalar bayat kalmasın: tablo yerinde güncellenir
R.Ayar = R.Ayar or table.Copy(R.Varsayilan)
for k, v in pairs(R.Varsayilan) do
     if R.Ayar[k] == nil then R.Ayar[k] = v end
end

-- { anahtar, etiket, en az, en çok, ondalık }
R.AyarAlanlari = {
     { "esik", "Eşik: açlık ya da susuzluk bu değere inince gelir", 5, 60, 0 },
     { "uykuEsik", "Uyku eşiği: uyku bu değere inince kahve getirir", 5, 60, 0 },
     { "bekleme", "Aynı karaktere iki ziyaret arası (dakika)", 10, 240, 0 },
     { "aclikSaat", "Açlık süresi: tokluktan sıfıra (saat)", 1, 24, 1 },
     { "susuzlukSaat", "Susuzluk süresi: tokluktan sıfıra (saat)", 1, 24, 1 },
}

R.NET = "SardonRepsus.Yonetim"
