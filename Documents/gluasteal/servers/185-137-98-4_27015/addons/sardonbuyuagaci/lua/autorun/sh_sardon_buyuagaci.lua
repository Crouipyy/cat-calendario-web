-- "addons\\sardonbuyuagaci\\lua\\autorun\\sh_sardon_buyuagaci.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Büyü Ağacı :: asa menüsü > Büyü Ağacı sekmesi.
-- Derslerden kazanılan Büyü Puanı ile 9 ağaçtaki büyüler açılır; kademeler
-- Karakter Gelişimi'ne bağlı, maliyet ve ders puanları Shine Admin'den ayarlanır.
if not SardonUtil then
     hook.Add("SardonUtilReady", "sardon_buyuagaci", function()
          SardonUtil:LoadAddon("sardon_buyuagaci", false)
     end)
else
     SardonUtil:LoadAddon("sardon_buyuagaci", false)
end
