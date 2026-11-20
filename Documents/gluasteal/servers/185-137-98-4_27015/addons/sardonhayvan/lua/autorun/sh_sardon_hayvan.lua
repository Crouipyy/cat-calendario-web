-- "addons\\sardonhayvan\\lua\\autorun\\sh_sardon_hayvan.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
if not SardonUtil then
     hook.Add("SardonUtilReady", "sardon_hayvan", function()
          SardonUtil:LoadAddon("sardon_hayvan", false)
     end)
else
     SardonUtil:LoadAddon("sardon_hayvan", false)
end
