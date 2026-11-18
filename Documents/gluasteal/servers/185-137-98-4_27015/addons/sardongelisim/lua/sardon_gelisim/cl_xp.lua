-- "addons\\sardongelisim\\lua\\sardon_gelisim\\cl_xp.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Gelişim :: dal XP bildirimi (istemci). Sunucu sv_xp.lua → net "SardonGelisim.XP".
-- G.SonXP: HUD şeridinin okuduğu son durum ([sardon] huds cl_legacy_1xp.lua L.DalSerit).
-- Aynı dalda art arda gelen kazançlar şeritte birleşir (heal tikleri, bakım).

local G = SardonGelisim

G.XPOlaylar = G.XPOlaylar or {}
local sesSon = 0

net.Receive("SardonGelisim.XP", function()
     local kat = G.Kategoriler[net.ReadUInt(4)]
     local e = {
          kazanc = net.ReadFloat(), bonus = net.ReadFloat(), x = net.ReadFloat(),
          eskiSv = net.ReadUInt(5), yeniSv = net.ReadUInt(5), kaynak = net.ReadString(),
          yorgunluk = net.ReadFloat(), t = RealTime()
     }
     if (!kat) then return end
     e.dal = kat.id

     local onceki = G.SonXP
     -- şerit hâlâ açıkken aynı dal: toplamı biriktir, başlangıç değerini koru
     if (onceki and onceki.dal == e.dal and RealTime() - onceki.t < 4.5) then
          e.toplam = (onceki.toplam or onceki.kazanc) + e.kazanc
          e.toplamBonus = (onceki.toplamBonus or onceki.bonus) + e.bonus
          e.ilkX = onceki.ilkX or (onceki.x - onceki.kazanc)
          e.ilkSv = onceki.ilkSv or onceki.eskiSv
          e.gelis = onceki.gelis
     else
          e.toplam, e.toplamBonus = e.kazanc, e.bonus
          e.ilkX = e.x - e.kazanc
          e.ilkSv = e.eskiSv
          e.gelis = RealTime()
     end
     G.SonXP = e

     local liste = G.XPOlaylar
     liste[#liste + 1] = e
     while (#liste > 30) do table.remove(liste, 1) end

     if (e.yeniSv > e.eskiSv) then
          surface.PlaySound("garrysmod/save_load4.wav")
          sesSon = RealTime()
     elseif (RealTime() - sesSon > 3) then
          sesSon = RealTime()
          surface.PlaySound("sardon_level/xp.mp3")
     end
     hook.Run("SardonGelisimXPGeldi", e)
end)

-- son 'sure' saniyede bu dala gelen XP (Biçim Defteri karnesi gibi yerler için)
function G.SonKazanc(dal, sure)
     local t, sinir = 0, RealTime() - (sure or 3)
     for i = #G.XPOlaylar, 1, -1 do
          local e = G.XPOlaylar[i]
          if (e.t < sinir) then break end
          if (e.dal == dal) then t = t + e.kazanc end
     end
     return math.floor(t + 0.5)
end

-- "≈3 iksir" gibi kısa metin (sonraki seviyeye kalan iş sayısı)
function G.KalanIsYazi(char, dal)
     local n = G.KalanIs(char, dal)
     if (!n) then return nil end
     local k = G.DalKaynaklari and G.DalKaynaklari[dal]
     return "≈" .. n .. " " .. (k and k.is or "tareas")
end
