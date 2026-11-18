-- "addons\\sardongorev\\lua\\sardon_gorev\\cl_2veri.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
/*
*   İstemci durumu: sunucudan gelen görev listesi (SardonGorev.Durum), olaylar (SardonGorev.Olay),
*   bildirim kuyruğu ve sunucuya istek yardımcısı.
*/
local G = SardonGorev

G.D = G.D or { gorevler = {}, bitti = {}, gunluk = {}, teklif = {} }
G.Bildirimler = G.Bildirimler or {}   -- ekrandaki kartlar
G.Afis = G.Afis or nil                -- büyük başlık afişi (başladı / bitti / karşılaşma)

function G.Iste(kod, yaz)
     net.Start("SardonGorev.Istek")
     net.WriteUInt(kod, 8)
     if yaz then yaz() end
     net.SendToServer()
end

function G.Takipte()
     local ilk
     for _, g in ipairs(G.D.gorevler or {}) do
          if not g.gizli then
               if g.takip then return g end
               ilk = ilk or g
          end
     end
     return ilk
end

function G.GorevBul(id)
     for _, g in ipairs(G.D.gorevler or {}) do if g.id == id then return g end end
end

-- Bir aktör herhangi bir hedefin konusu mu (baş üstü işareti için)
function G.AktorHedefte(no)
     for _, g in ipairs(G.D.gorevler or {}) do
          for _, h in ipairs(g.hedefler or {}) do
               if h.isaret and h.isaret.aktor == no and not h.tamam then return g end
          end
     end
end

net.Receive("SardonGorev.Durum", function()
     local onceki = G.D
     G.D = G.OkuTablo()
     G.D.gorevler = G.D.gorevler or {}
     G.D.teklif = G.D.teklif or {}
     G.D.alindi = RealTime()

     -- yeni gelen hedefleri kısa süre vurgula
     local eski = {}
     for _, g in ipairs(onceki.gorevler or {}) do
          for _, h in ipairs(g.hedefler or {}) do eski[g.id .. "|" .. h.metin] = true end
     end
     for _, g in ipairs(G.D.gorevler) do
          for _, h in ipairs(g.hedefler or {}) do
               if not eski[g.id .. "|" .. h.metin] then h.yeni = RealTime() end
          end
     end
     hook.Run("SardonGorevDurum", G.D)
end)

/*
*   Bildirimler
*/
function G.Bildir(t)
     t.bas = RealTime()
     t.sure = t.sure or 5
     table.insert(G.Bildirimler, 1, t)
     while #G.Bildirimler > 5 do table.remove(G.Bildirimler) end
end

function G.AfisGoster(t)
     t.bas = RealTime()
     t.sure = t.sure or 5.5
     G.Afis = t
end

local OLAY = {}

OLAY.basladi = function(t)
     G.AfisGoster({ ust = G.Buyuk(G.Tur(t.tur).ad), baslik = t.ad, alt = t.ozet, renk = G.TurRenk(t.tur) })
     G.Cal("basla")
end

OLAY.karsilasma = function(t)
     G.AfisGoster({ ust = "ENCUENTRO", baslik = t.ad, alt = t.ozet, renk = G.TurRenk("karsilasma"), sure = 4.5 })
     G.Cal("karsilasma")
end

OLAY.bitti = function(t)
     G.AfisGoster({ ust = "MISIÓN COMPLETADA", baslik = t.ad, alt = t.mesaj, renk = G.R.altinAcik, oduller = t.oduller, sure = 6.5 })
     G.Cal("bitti")
end

OLAY.basarisiz = function(t)
     G.AfisGoster({ ust = "MISIÓN FALLIDA", baslik = t.ad, alt = t.mesaj, renk = G.R.kirmizi, sure = 5 })
     G.Cal("basarisiz")
end

OLAY.adim = function(t)
     -- adım adı takipçide görünür; ayrıca kart göstermiyoruz
     G.SonAdim = { id = t.id, ad = t.adim, bas = RealTime() }
end

OLAY.hedef = function(t)
     if t.tamam then
          G.Bildir({ tur = "hedef", metin = t.metin, tamam = true, sure = 3.5 })
          G.Cal("hedef")
     else
          G.Bildir({ tur = "ilerleme", metin = t.metin, sayi = t.sayi, gerek = t.gerek, sure = 2.5 })
          G.Cal("ilerleme")
     end
end

OLAY.bildirim = function(t)
     G.Bildir({ tur = t.tur or "bilgi", metin = t.metin, sure = t.sure or 5 })
     if t.tur == "uyari" then G.Cal("basarisiz") else G.Cal("ilerleme") end
end

OLAY.odul = function(t)
     if not t.oduller or #t.oduller == 0 then return end
     G.Bildir({ tur = "odul", metin = table.concat(t.oduller, "  ·  "), sure = 4.5 })
     G.Cal("hedef")
end

net.Receive("SardonGorev.Olay", function()
     local t = G.OkuTablo()
     local f = OLAY[t.t or ""]
     if f then f(t) end
     hook.Run("SardonGorevOlay", t)
end)

-- Yükleme sonrası durumu iste (sunucu karakter yüklenince de gönderiyor)
timer.Simple(4, function()
     if IsValid(LocalPlayer()) then G.Iste(G.ISTEK.HAZIR) end
end)

/*
*   Komutlar
*/
concommand.Add("sardon_gorev_takip", function(_, _, args)
     if args[1] then G.Iste(G.ISTEK.TAKIP, function() net.WriteString(args[1]) end) end
end)
