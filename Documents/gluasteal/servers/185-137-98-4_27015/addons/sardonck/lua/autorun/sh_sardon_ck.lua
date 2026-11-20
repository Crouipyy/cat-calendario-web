-- "addons\\sardonck\\lua\\autorun\\sh_sardon_ck.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
if not SardonUtil then
     hook.Add("SardonUtilReady", "sardon_ck", function()
          SardonUtil:LoadAddon("sardon_ck", false)
     end)
else
     SardonUtil:LoadAddon("sardon_ck", false)
end
