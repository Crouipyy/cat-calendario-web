-- "addons\\sardonkitap\\lua\\autorun\\sh_sardon_kitap.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Birinci Yıl Kitapları :: kanondaki okul kitapları gerçek eşya; her biri var olan bir sistemi açar.
-- Goshawk / Switch / Trimble: kitaptan büyü öğrenme (oku → rün çiz → acemi büyü)
-- Jigger: Temel iksir tarifleri · Spore: bitki sayfaları · Scamander: yaratık sayfaları
-- Bagshot: gezilen yerlerin tarihi · Waffling: oyuncunun asasına özel sayfa
-- Ayrıca: kitapçı sahnesi, malzeme mektubu, okul kazanı, ders sayfası, kenar notları,
-- ikinci el kitap, her yıl baykuşla yeni liste, yıl sonu sınavı.
if not SardonUtil then
     hook.Add("SardonUtilReady", "sardon_kitap", function()
          SardonUtil:LoadAddon("sardon_kitap", false)
     end)
else
     SardonUtil:LoadAddon("sardon_kitap", false)
end
