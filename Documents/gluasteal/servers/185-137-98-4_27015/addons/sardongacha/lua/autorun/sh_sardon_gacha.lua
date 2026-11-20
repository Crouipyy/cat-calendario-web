-- "addons\\sardongacha\\lua\\autorun\\sh_sardon_gacha.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
if not SardonUtil then
     hook.Add("SardonUtilReady", "sardon_gacha", function()
          SardonUtil:LoadAddon("sardon_gacha", false)
     end)
else
     SardonUtil:LoadAddon("sardon_gacha", false)
end
