-- "addons\\sardonshineadmin\\lua\\autorun\\sh_shineadmin_init.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
if not SardonUtil then
     hook.Add("SardonUtilReady", "sardon_shineadmin", function()
          SardonUtil:LoadAddon("sardon_shineadmin", false)
     end)
else
     SardonUtil:LoadAddon("sardon_shineadmin", false)
end
