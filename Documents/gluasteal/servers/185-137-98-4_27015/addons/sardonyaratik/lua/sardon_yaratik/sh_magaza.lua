-- "addons\\sardonyaratik\\lua\\sardon_yaratik\\sh_magaza.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- [sardon] yaratik :: "Yaratık Bakıcısı" mağazası (sardon_shopic)
--
-- sardon_shopic mağaza tablosunu her yüklemede baştan kurar; "SardonShopKur" kancasıyla eklenir.
-- Para OnBuy'dan ÖNCE düştüğü için CanBuy sunucuda tam doğrulama yapar (Y.AlabilirSunucu).
-- Ürün sırası sabit olmalı (satın alma isteği sıra numarasıyla gider).

local Y = SardonYaratik
local A = Y.Ayar

local MAGAZA = "YaratikStore"

local function ModelIkonu(model, renk, bodygroup)
     return function()
          local kap = vgui.Create("Panel")
          local ikon = kap:Add("SpawnIcon")
          ikon:SetModel(model, 0, bodygroup or "")
          ikon:SetMouseInputEnabled(false)

          function kap:PerformLayout(w, h)
               ikon:SetSize(w * 0.62, w * 0.62)
               ikon:Center()
          end

          function kap:Paint(w, h)
               surface.SetDrawColor(renk.r, renk.g, renk.b, 60)
               surface.DrawRect(0, 0, w, h)
          end

          return kap
     end
end

local function Alabilir(cesit, ad)
     return function(ply)
          if SERVER then return Y.AlabilirSunucu(ply, cesit, ad) end
          -- istemci: yalnız gösterim (sunucu yine denetler)
          local char = ply:GetCharacter()
          if not char then return false end
          if cesit == "yumurta" then
               local tur = Y.Turler[ad]
               local izin, neden = Y.SinifIzni(char, tur.sinif)
               if not izin then return neden end
               if Y.Benim and (Y.Benim.yumurta or 0) >= A.KuluckaSiniri then
                    return "En çok " .. A.KuluckaSiniri .. " yumurta"
               end
          end
          return true
     end
end

local function Satin(cesit, ad)
     return function(ply)
          if Y.SatinAl then Y.SatinAl(ply, cesit, ad) end
     end
end

local SINIF_RENK = {
     [2] = {Color(70, 150, 90), Color(130, 210, 140)},
     [3] = {Color(190, 140, 50), Color(236, 196, 100)},
     [4] = {Color(120, 70, 170), Color(190, 130, 230)},
}

function Y.MagazaKur(shops)
     if not istable(shops) then return end

     local yumurtalar = {}
     for _, id in ipairs(Y.TurSirasi) do
          local tur = Y.Turler[id]
          if tur and tur.fiyat then
               yumurtalar[#yumurtalar + 1] = {
                    name = tur.ad .. " Yumurtası  (" .. Y.SinifKod(tur.sinif) .. ")",
                    price = tur.fiyat,
                    OnBuy = Satin("yumurta", id),
                    CanBuy = Alabilir("yumurta", id),
                    BuildIcon = ModelIkonu(tur.model, (SINIF_RENK[tur.sinif] or SINIF_RENK[2])[1]),
               }
          end
     end

     local bakim = {}
     for _, yem in ipairs(Y.YemSirasi) do
          local yv = Y.Yemler[yem]
          bakim[#bakim + 1] = {
               name = yv.ad .. " (" .. yv.paket .. " adet)",
               price = yv.fiyat,
               OnBuy = Satin("yem", yem),
               CanBuy = Alabilir("yem", yem),
               BuildIcon = ModelIkonu(yv.model, Color(110, 150, 80)),
          }
     end
     bakim[#bakim + 1] = {
          name = "Yaratık Fırçası",
          price = 10,
          OnBuy = Satin("firca"),
          CanBuy = Alabilir("firca"),
          BuildIcon = ModelIkonu(A.FircaModel, Color(110, 150, 80)),
     }
     bakim[#bakim + 1] = {
          name = "Taşıma Kafesi",
          price = 13,
          OnBuy = Satin("kafes"),
          CanBuy = Alabilir("kafes"),
          BuildIcon = ModelIkonu(A.KafesModel, Color(110, 150, 80)),
     }
     -- sıra sabit: yeni ürünler sona
     bakim[#bakim + 1] = {
          name = "Yakalama Çantası",
          price = 15,
          OnBuy = Satin("cuval"),
          CanBuy = Alabilir("cuval"),
          BuildIcon = ModelIkonu(A.CuvalModel, Color(110, 150, 80)),
     }

     shops[MAGAZA] = {
          name = "Yaratık Bakıcısı",
          mdl = "models/lynx/newtscamander_percivalt.mdl",
          tabs = {
               ["Yumurtalar"] = {
                    order = 1,
                    desc = "Kuluçkada nadirlik belirlenir · XXX için SYB gerekir",
                    icon = "W5r4sKb",
                    colors = SINIF_RENK[3],
                    items = yumurtalar,
               },
               ["Bakım"] = {
                    order = 2,
                    desc = "Yem, fırça, taşıma kafesi ve yakalama çantası",
                    icon = "W5r4sKb",
                    colors = SINIF_RENK[2],
                    items = bakim,
               },
          },
     }
end

hook.Add("SardonShopKur", "SardonYaratik", Y.MagazaKur)

if SardonShop and SardonShop.Shops then
     Y.MagazaKur(SardonShop.Shops)
end
