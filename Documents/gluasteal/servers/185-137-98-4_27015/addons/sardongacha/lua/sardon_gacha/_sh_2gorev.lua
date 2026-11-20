-- "addons\\sardongacha\\lua\\sardon_gacha\\_sh_2gorev.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
/*
*   Görev sistemine ([sardon] gorev) iki ödül türü: Adak ve Dilek Bileti. Görev Atölyesi'nde
*   "Ödüller" listesinde görünür. Görev eklentisi bizden sonra yüklenebilir ve şema dosyası canlı
*   yenilenince G.Sema baştan kurulur; bu yüzden kayıt bir zamanlayıcıyla tazelenir.
*/
local SG = SardonGacha

local function Ekle(G, id, t)
     t.id = id
     G.Sema.Odul[id] = t
     local sira = G.SemaSira and G.SemaSira.Odul
     if sira and not table.HasValue(sira, id) then sira[#sira + 1] = id end
end

local function Kur()
     local G = SardonGorev
     if not G or not G.Sema or not G.Sema.Odul then return end
     if G.Sema.Odul.adak and (CLIENT or (G.Odul and G.Odul.adak)) then return end

     Ekle(G, "adak", {
          ad = "Ofrenda (deseo de varita)",
          alanlar = { { k = "miktar", ad = "Ofrenda", tip = "sayi", v = 160, min = 1, max = 100000 } },
          ozet = function(e) return SG.Sayi(e.miktar or 0) .. " " .. (SG.Ayar.adakAd or "Ofrenda") end,
     })
     Ekle(G, "dilek_bileti", {
          ad = "Boleto de deseo (varita)",
          alanlar = { { k = "miktar", ad = "Boleto", tip = "sayi", v = 1, min = 1, max = 100 } },
          ozet = function(e) return SG.Sayi(e.miktar or 0) .. " " .. (SG.Ayar.biletAd or "Boleto de deseo") end,
     })

     if SERVER and G.Odul then
          G.Odul.adak = function(ply, od, o)
               SG.CuzdanEkle(ply, "adak", math.floor(tonumber(od.miktar) or 0), "Misión: " .. (o and o.def and o.def.ad or "?"), true)
          end
          G.Odul.dilek_bileti = function(ply, od, o)
               SG.CuzdanEkle(ply, "bilet", math.floor(tonumber(od.miktar) or 0), "Misión: " .. (o and o.def and o.def.ad or "?"), true)
          end
     end
end

timer.Create("SardonGacha.GorevOdul", 10, 0, Kur)
timer.Simple(1, Kur)
