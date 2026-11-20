-- "addons\\sardonkira\\lua\\autorun\\sh_kira_init.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
if not SardonUtil then
     hook.Add("SardonUtilReady", "sardon_kira", function()
          SardonUtil:LoadAddon("sardon_kira", false)
     end)
else
     SardonUtil:LoadAddon("sardon_kira", false)
end