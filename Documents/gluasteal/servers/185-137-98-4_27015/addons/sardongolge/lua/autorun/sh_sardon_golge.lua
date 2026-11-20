-- "addons\\sardongolge\\lua\\autorun\\sh_sardon_golge.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Gölge :: Gerçeklik Hançeri (saplananın görünümünü kopyalayıp ona dönüşme) + Gölge, karaborsa
-- levazımatçısı ([sardon] gorev dünya aktörü; haftalık hançer hakkı, rastgele noktalara ışınlanır).
if not SardonUtil then
     hook.Add("SardonUtilReady", "sardon_golge", function()
          SardonUtil:LoadAddon("sardon_golge", false)
     end)
else
     SardonUtil:LoadAddon("sardon_golge", false)
end
