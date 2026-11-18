-- "addons\\sardongorev\\lua\\autorun\\sh_sardon_gorev.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
if not SardonUtil then
     hook.Add("SardonUtilReady", "sardon_gorev", function()
          SardonUtil:LoadAddon("sardon_gorev", false)
     end)
else
     SardonUtil:LoadAddon("sardon_gorev", false)
end
