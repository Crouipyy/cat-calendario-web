-- "addons\\sardonbakanlik\\lua\\sardon_bakanlik\\_sh_net.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Bakanlık :: ağ katmanı. Tek istek kanalı + eylem tablosu ([sardon] gazete deseni).
--
--   istemci -> sunucu   SardonBakanlik.Istek   eylem adı + tablo        B.Iste(eylem, arg)
--   sunucu -> istemci   SardonBakanlik.Veri    anahtar + tablo          B.Gonder(ply, anahtar, tablo)
--   sunucu -> istemci   SardonBakanlik.Bildirim metin + tür (0/1/2)     B.Bildir(ply, metin, tur)
--   sunucu -> istemci   SardonBakanlik.Not     tablo (HUD olayı)        B.NotGonder(alicilar, tablo)
--
-- Tablolar net.WriteTable ile taşınır: util.JSONToTable "[1 2 3]" gibi metinleri Vector'a
-- çevirdiği için serbest metin taşıyan paketlerde JSON kullanılmıyor.

local B = SardonBakanlik

B.NET_ISTEK = "SardonBakanlik.Istek"
B.NET_VERI = "SardonBakanlik.Veri"
B.NET_BILDIRIM = "SardonBakanlik.Bildirim"
B.NET_NOT = "SardonBakanlik.Not"

if SERVER then
     util.AddNetworkString(B.NET_ISTEK)
     util.AddNetworkString(B.NET_VERI)
     util.AddNetworkString(B.NET_BILDIRIM)
     util.AddNetworkString(B.NET_NOT)

     B.Istekler = B.Istekler or {}

     -- izin: nil = karakteri olan herkes; yazı = B.Yapabilir(ply, izin) şartı
     function B.Eylem(ad, izin, fn)
          B.Istekler[ad] = {izin = izin, fn = fn}
     end

     function B.Gonder(ply, anahtar, tablo)
          if not IsValid(ply) then return end
          net.Start(B.NET_VERI)
               net.WriteString(anahtar)
               net.WriteTable(tablo or {})
          net.Send(ply)
     end

     -- tur: 0 bilgi, 1 başarı, 2 hata
     function B.Bildir(ply, metin, tur)
          if not IsValid(ply) then return end
          net.Start(B.NET_BILDIRIM)
               net.WriteString(tostring(metin or ""))
               net.WriteUInt(tur or 0, 2)
          net.Send(ply)
     end

     function B.NotGonder(alicilar, tablo)
          if istable(alicilar) and #alicilar == 0 then return end
          net.Start(B.NET_NOT)
               net.WriteTable(tablo)
          net.Send(alicilar)
     end

     -- Jeton kovası: 8 isteğe kadar art arda, saniyede 5 yenilenir
     local kova = {}

     local function HizUygun(ply)
          local simdi = CurTime()
          local k = kova[ply]
          if not k then
               k = {n = 8, an = simdi}
               kova[ply] = k
          end
          k.n = math.min(8, k.n + (simdi - k.an) * 5)
          k.an = simdi
          if k.n < 1 then return false end
          k.n = k.n - 1
          return true
     end

     net.Receive(B.NET_ISTEK, function(uzunluk, ply)
          if not IsValid(ply) or uzunluk > 8 * 24000 then return end

          local eylem = net.ReadString()
          local e = B.Istekler[eylem]
          if not e then return end
          if not HizUygun(ply) then return end

          local char = ply:GetCharacter()
          if not char then return end

          local arg = net.ReadTable()
          if not istable(arg) then arg = {} end

          if e.izin then
               local ok, sebep = B.Yapabilir(ply, e.izin)
               if not ok then
                    B.Bildir(ply, sebep, 2)
                    return
               end
          end

          local ok, hata = xpcall(e.fn, debug.traceback, ply, arg, char)
          if not ok then
               ErrorNoHalt("[Sardon Bakanlık] '" .. eylem .. "' eylemi hata verdi:\n" .. tostring(hata) .. "\n")
               B.Bildir(ply, "Defter bu işlemi yazamadı (sunucu hatası).", 2)
          end
     end)

     B.Kanca("PlayerDisconnected", "SardonBakanlik.Net", function(ply) kova[ply] = nil end)
else
     B.Veri = B.Veri or {}       -- [anahtar] = son gelen tablo
     B.VeriAn = B.VeriAn or {}   -- [anahtar] = RealTime()

     function B.Iste(eylem, arg)
          net.Start(B.NET_ISTEK)
               net.WriteString(eylem)
               net.WriteTable(arg or {})
          net.SendToServer()
     end

     net.Receive(B.NET_VERI, function()
          local anahtar = net.ReadString()
          local tablo = net.ReadTable()
          B.Veri[anahtar] = tablo
          B.VeriAn[anahtar] = RealTime()
          hook.Run("SardonBakanlikVeri", anahtar, tablo)
     end)

     net.Receive(B.NET_BILDIRIM, function()
          local metin = net.ReadString()
          local tur = net.ReadUInt(2)
          if hook.Run("SardonBakanlikBildirim", metin, tur) ~= true then
               -- defter kapalıysa Helix bildirimi
               local ply = LocalPlayer()
               if IsValid(ply) and ply.Notify then ply:Notify(metin) else chat.AddText(Color(190, 162, 104), "[Bakanlık] ", color_white, metin) end
          end
     end)

     net.Receive(B.NET_NOT, function()
          hook.Run("SardonBakanlikNot", net.ReadTable())
     end)
end
