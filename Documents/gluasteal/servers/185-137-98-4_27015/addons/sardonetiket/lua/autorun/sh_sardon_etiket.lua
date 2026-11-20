-- "addons\\sardonetiket\\lua\\autorun\\sh_sardon_etiket.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Etiket :: Discord sunucu etiketi (SHNE) takan oyuncuya aktif saat başına ShineCoin + TAB rozeti.
if not SardonUtil then
     hook.Add("SardonUtilReady", "sardon_etiket", function()
          SardonUtil:LoadAddon("sardon_etiket", false)
     end)
else
     SardonUtil:LoadAddon("sardon_etiket", false)
end
