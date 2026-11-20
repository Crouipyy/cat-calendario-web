-- "addons\\sardonekonomi\\lua\\autorun\\sh_sardon_ekonomi.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- [sardon] ekonomi — tavan, vergi, para kaydı, tüccar, pazar (plan: 2026-11-07)
if not SardonUtil then
     hook.Add("SardonUtilReady", "sardon_ekonomi", function()
          SardonUtil:LoadAddon("sardon_ekonomi", false)
     end)
else
     SardonUtil:LoadAddon("sardon_ekonomi", false)
end
