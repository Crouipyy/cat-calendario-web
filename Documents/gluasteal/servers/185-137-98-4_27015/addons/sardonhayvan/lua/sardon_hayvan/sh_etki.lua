-- "addons\\sardonhayvan\\lua\\sardon_hayvan\\sh_etki.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Hayvan :: donma etkisinin yavaşlatması. Hareket tahmini istemcide de
-- aynı sonucu versin diye ortak dosyada; bitiş zamanı NW2 ile geliyor (sv_etki.lua).

hook.Add("SetupMove", "SardonHayvan.Donma", function(ply, mv)
     local bitis = ply:GetNW2Float("SardonHayvan.Donma", 0)
     if (bitis <= 0 or CurTime() >= bitis) then return end

     local etki = SardonHayvan.Etkiler and SardonHayvan.Etkiler.donma
     local k = etki and etki.yavas or 0.6

     mv:SetMaxClientSpeed(mv:GetMaxClientSpeed() * k)
     mv:SetMaxSpeed(mv:GetMaxSpeed() * k)
end)
