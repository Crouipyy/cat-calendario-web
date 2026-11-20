-- "addons\\sardonkira\\lua\\sardon_kira\\cl_4dene.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Kira v2 :: "Oyunda dene" alıcısı (yalnız süper yetkiliye gelir). Parçalar doğrudan diske yazılır
-- (belleğe 100 MB toplanmaz), bitince game.MountGMA. Bağlı .dat oyun kapanana kadar silinemez; yeni derleme
-- her seferinde yeni dosya adı/yol kullanır.
local K = SardonKira
local OP = K.OP

local acik = {}   -- [dosya] = {f, n, son}

function K.DenemeParca()
     local dosya = net.ReadString()
     local i, n, boy = net.ReadUInt(16), net.ReadUInt(16), net.ReadUInt(32)
     local veri = net.ReadData(boy)
     if not dosya:match("^[a-z0-9]+_%d+$") then return end
     local yol = "sardon_kira_dene_" .. dosya .. ".dat"
     local a = acik[dosya]
     if i == 1 then
          if a and a.f then a.f:Close() end
          local f = file.Open(yol, "wb", "DATA")
          if not f then
               K.Iste(OP.DENE_ONAY, { dosya = dosya, hata = "dosya açılamadı" })
               return
          end
          a = { f = f, n = n, son = 0, bekleyen = {} }
          acik[dosya] = a
          K.Bildirim("Deneme paketi indiriliyor (" .. n .. " parça)...")
     end
     if not a then return end
     -- parçalar sırayla yazılır; pencere içinde önden gelen bekletilir
     a.bekleyen[i] = veri
     while a.bekleyen[a.son + 1] do
          a.son = a.son + 1
          a.f:Write(a.bekleyen[a.son])
          a.bekleyen[a.son] = nil
     end
     K.Iste(OP.DENE_ONAY, { dosya = dosya, i = a.son })
     if a.son >= a.n then
          a.f:Close()
          acik[dosya] = nil
          local ok, liste = game.MountGMA("data/" .. yol)
          if ok then
               K.Bildirim("Deneme paketi bağlandı (" .. #(liste or {}) .. " dosya).")
               K.Iste(OP.DENE_ONAY, { dosya = dosya, i = a.son, bagli = true })
          else
               K.Iste(OP.DENE_ONAY, { dosya = dosya, hata = "MountGMA başarısız" })
          end
     end
end
