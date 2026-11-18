-- "addons\\sardonbakanlik\\lua\\autorun\\sh_sardon_bakanlik.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- [sardon] bakanlik :: Büyü Bakanlığı "Sicil Defteri" (daireler, hiyerarşi, sicil, olay/sevk,
-- dosya ve delil, ceza kanunu, Azkaban, İz Odası, kararname, hazine, Büyüceşûra).
if not SardonUtil then
     hook.Add("SardonUtilReady", "sardon_bakanlik", function()
          SardonUtil:LoadAddon("sardon_bakanlik", false)
     end)
else
     SardonUtil:LoadAddon("sardon_bakanlik", false)
end
