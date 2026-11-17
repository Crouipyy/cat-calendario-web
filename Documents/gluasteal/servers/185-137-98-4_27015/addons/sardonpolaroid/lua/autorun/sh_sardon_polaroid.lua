-- "addons\\sardonpolaroid\\lua\\autorun\\sh_sardon_polaroid.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
if not SardonUtil then
     hook.Add("SardonUtilReady", "sardon_polaroid", function()
          SardonUtil:LoadAddon("sardon_polaroid", false)
     end)
else
     SardonUtil:LoadAddon("sardon_polaroid", false)
end