-- "addons\\sardonakran\\lua\\autorun\\sh_sardon_akran.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Akran Yardımı :: kıdemli öğrenciler yeni gelenlere Temel büyü öğretir.
-- Akış: asa menüsü > Akran Yardımı'ndan teklif → kütüphanede raftaki kitabı bul → 7 dk oku
-- → talim alanında büyünün rününü asayla havada çiz → öğretmen onaylar, büyü öğrenilir.
if not SardonUtil then
     hook.Add("SardonUtilReady", "sardon_akran", function()
          SardonUtil:LoadAddon("sardon_akran", false)
     end)
else
     SardonUtil:LoadAddon("sardon_akran", false)
end
