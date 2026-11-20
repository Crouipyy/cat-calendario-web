-- "addons\\sardonrevir\\lua\\autorun\\sh_sardon_revir.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Revir Nöbeti :: Şifa dalı (Karakter Gelişimi) için günlük gönüllü nöbet.
-- Akış: Madam Pomfrey'e gönüllü ol → 3 yatağa hasta gelir → dinle / muayene et / asayla tara
-- → masadaki Hastalık Defteri'nden teşhis koy → tedavinin büyüsünü havada rünüyle çiz
-- (bilmediğin büyü kılavuzla ve tutunma şansıyla) → Şifa deneyimi, büyü ustalığı, Şifa dal puanı.
-- Rün motoru [sardon] akran'dan (SardonAkran), yürüyüş yolları Fieldguide'dan (GMap) gelir.
if not SardonUtil then
     hook.Add("SardonUtilReady", "sardon_revir", function()
          SardonUtil:LoadAddon("sardon_revir", false)
     end)
else
     SardonUtil:LoadAddon("sardon_revir", false)
end
