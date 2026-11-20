-- "addons\\sardonrepsus\\lua\\autorun\\sh_sardon_repsus.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- [sardon] repsus — acıkan/susayan oyuncuya ev cini Repsus yiyecek ve içecek getirir;
-- açlık/susuzluk tüketimi (gamemode needs eklentisi) buradan yönetilir. Shine Admin › Repsus.
if not SardonUtil then
     hook.Add("SardonUtilReady", "sardon_repsus", function()
          SardonUtil:LoadAddon("sardon_repsus", false)
     end)
else
     SardonUtil:LoadAddon("sardon_repsus", false)
end
