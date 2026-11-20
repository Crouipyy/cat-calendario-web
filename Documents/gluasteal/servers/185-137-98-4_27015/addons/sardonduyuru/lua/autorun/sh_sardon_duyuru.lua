-- "addons\\sardonduyuru\\lua\\autorun\\sh_sardon_duyuru.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- [sardon] duyuru — rol dışı (OOC) oyun içi duyuru: /Duyuru, Shine Admin › Duyuru, konsol sardon_duyuru.
-- Ekranda Legacy HUD diliyle üst ortada bant + sohbet satırı; geri sayımlı duyurular pusula altında kalır.
if not SardonUtil then
     hook.Add("SardonUtilReady", "sardon_duyuru", function()
          SardonUtil:LoadAddon("sardon_duyuru", false)
     end)
else
     SardonUtil:LoadAddon("sardon_duyuru", false)
end
