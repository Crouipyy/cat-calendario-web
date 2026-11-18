-- "addons\\sardonbaykus\\lua\\autorun\\sh_baykus_init.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
if not SardonUtil then
     hook.Add("SardonUtilReady", "sardon_baykus", function()
          SardonUtil:LoadAddon("sardon_baykus", false)
     end)
else
     SardonUtil:LoadAddon("sardon_baykus", false)
end