-- "addons\\sardonekonomi\\lua\\sardon_ekonomi\\_sh_1ayar.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
--[[
     Sardon Ekonomi :: ayarlar (paylaşılan)

     Kararlar (kullanıcı, 2026-11-07; plan ~/.claude/plans/cryptic-dancing-minsky.md):
       - Kanon küçük ölçek, yalnız Galleon. Düzenli oyuncu ~15 G/gün; üst eşyalar ~3 ayda.
       - Saatlik maaş YOK. Para üretimden (NPC tüccar) ve görev panosundan gelir.
       - Günlük sert tavan 25 G: yalnız sisteme YENİ giren para (NPC satışı + görev) sayılır,
         hesap (SteamID64) başına. Oyuncular arası satış / bahis / hediye tavana girmez.
       - %5 ticaret vergisi (oyuncular arası aktarım, havale, NPC satışı) Bakanlık Hazinesi'ne.
       - Ölüm: cebin %25'i yok olur, seviye 10'a kadar muaf.
       - Başlangıç (2026-11-13 açılış kararı): öğrenci 20 G, yetişkin 10 G; ilk asa 7 G paradan düşer.

     API (sunucu, sv_1cekirdek.lua):
       SardonEkonomi.Kazandir(ply, miktar, kaynak, {ertele = bool, vergisiz = bool})
       SardonEkonomi.KalanTavan(ply)
       SardonEkonomi.Aktar(gonderenPly, alanPly, miktar, tur)
       SardonEkonomi.Harca(ply, miktar, kaynak, {hazineye = bool, aciklama = str})
       SardonEkonomi.Baglam(kaynak, tur, fn, ...)   -- fn içindeki para hareketleri bu kaynakla kaydedilir
]]

SardonEkonomi = SardonEkonomi or {}
local E = SardonEkonomi

E.AyarVarsayilan = {
     tavan = 25,                 -- günlük basılan para tavanı (Galleon, hesap başına)
     vergi = 0.05,               -- ticaret vergisi oranı
     olumOran = 0.25,            -- ölümde cepten yok olan pay
     olumMuafSeviye = 10,        -- bu seviyenin ALTINDAKİLER ölümde para kaybetmez
     baslangicOgrenci = 20,      -- ilk asa 7 + kayış 3 + 2 kitap 8 + 2 (diğer kitaplar kazanılarak)
     baslangicYetiskin = 10,     -- ilk asa 7 + 3
     ilkAsaFiyat = 7,
     kayitGun = 30,              -- ham para kaydı kaç gün tutulur (günlük özetler kalıcı)
}

E.Ayar = E.Ayar or {}
for k, v in pairs(E.AyarVarsayilan) do
     if E.Ayar[k] == nil then E.Ayar[k] = v end
end

-- Gün anahtarı: Türkiye saatiyle 07:00'den ertesi 07:00'ye (Şans sistemiyle aynı sıfırlama)
E.SaatDilimi = 3
E.SifirlamaSaati = 7

function E.GunAnahtari(t)
     return os.date("!%Y-%m-%d", (t or os.time()) + (E.SaatDilimi - E.SifirlamaSaati) * 3600)
end

function E.SonrakiSifirlama(t)
     t = t or os.time()
     local kayik = t + (E.SaatDilimi - E.SifirlamaSaati) * 3600
     return t + (86400 - kayik % 86400)
end

function E.Para(n)
     return string.Comma(math.floor(tonumber(n) or 0)) .. " Galleon"
end
