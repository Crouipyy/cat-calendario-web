-- "addons\\sardoncigirtkan\\lua\\autorun\\sh_sardon_cigirtkan.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Çığırtkan (Howler) :: yükleyici. Akış ve ayarlar: lua/sardon_cigirtkan/_sh_config.lua
if not SardonUtil then
     hook.Add("SardonUtilReady", "sardon_cigirtkan", function()
          SardonUtil:LoadAddon("sardon_cigirtkan", false)
     end)
else
     SardonUtil:LoadAddon("sardon_cigirtkan", false)
end
