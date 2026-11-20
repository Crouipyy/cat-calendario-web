-- "addons\\sardonyaratik\\lua\\sardon_yaratik\\_sh_4esya.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- [sardon] yaratik :: Helix eşyaları
--
-- Yaratığın kendisi eşya DEĞİL (sunucu tablosunda satır). Taşıma kafesi ve yumurta eşyaları
-- yalnız kayda işaret eder (data.yid); böylece eşya kopyalama/hayalet satır sorunları yaratığı
-- çoğaltamaz, devir sunucuda doğrulanır. Ürünler [sardon] iksir'in "ingredient" eşyası
-- (data.type = ürün adı, data.count = adet).

local Y = SardonYaratik
local A = Y.Ayar

local function TurAd(tur)
     local t = Y.Turler[tur]
     return t and t.ad or "Yaratık"
end

------------------------------------------------------------------------ yem

do
     local ITEM = ix.item.Register("yaratik_yem", nil, false, nil, true)
     ITEM.name = "Yaratık Yemi"
     ITEM.description = "Sihirli yaratıklar için yem. Yaratığa bakıp E ile besle ya da vivaryumdaki yemliğe koy; sen yokken aç kalan yaratıkların oradan yer."
     ITEM.model = "models/sbs/hogsmeade/hm/hgs_comc_sack_of_stuff1.mdl"
     ITEM.category = "Sihirli Yaratıklar"
     ITEM.width = 1
     ITEM.height = 1

     function ITEM:GetName()
          local y = Y.Yemler[self:GetData("yem", "genel")]
          return y and y.ad or self.name
     end

     function ITEM:GetModel()
          local y = Y.Yemler[self:GetData("yem", "genel")]
          return y and y.model or self.model
     end

     function ITEM:PopulateTooltip(tooltip)
          local satir = tooltip:AddRowAfter("name", "adet")
          satir:SetBackgroundColor(Color(120, 150, 90))
          satir:SetText("Adet: " .. self:GetData("adet", 1))
          satir:SizeToContents()

          local yem = self:GetData("yem", "genel")
          local sevenler = {}
          for _, id in ipairs(Y.TurSirasi) do
               local t = Y.Turler[id]
               if Y.YemUygunluk(t, yem) >= 1 then sevenler[#sevenler + 1] = t.ad end
          end
          local s2 = tooltip:AddRowAfter("adet", "sevenler")
          s2:SetText(Y.Yemler[yem] and Y.Yemler[yem].genel and "Todas las criaturas (media eficacia)" or ("Les gusta: " .. (#sevenler > 0 and table.concat(sevenler, ", ") or "—")))
          s2:SizeToContents()
     end

     ITEM.functions.yemlik = {
          name = "Poner en comedero",
          icon = "icon16/basket_put.png",
          OnRun = function(item)
               if SERVER and Y.YemlikeKoy then Y.YemlikeKoy(item.player, item) end
               return false
          end,
          OnCanRun = function(item)
               if IsValid(item.entity) then return false end
               return Y.KendiDunyasinda and Y.KendiDunyasinda(item.player) or false
          end
     }
end

------------------------------------------------------------------------ fırça

do
     local ITEM = ix.item.Register("yaratik_firca", nil, false, nil, true)
     ITEM.name = "Yaratık Fırçası"
     ITEM.description = "Sert kıllı bakım fırçası. Envanterinde varken yaratığa bakıp E › Fırçala ile tüylerini temizlersin. Kullandıkça kılları aşınır."
     ITEM.model = A.FircaModel
     ITEM.category = "Sihirli Yaratıklar"
     ITEM.width = 1
     ITEM.height = 1

     function ITEM:PopulateTooltip(tooltip)
          local en = A.FircaDayanim or 30
          local kalan = self:GetData("dayanim", en)
          local satir = tooltip:AddRowAfter("name", "dayanim")
          satir:SetBackgroundColor(kalan <= en * 0.2 and Color(170, 90, 70) or Color(120, 150, 90))
          satir:SetText("Kalan fırçalama: " .. kalan .. "/" .. en)
          satir:SizeToContents()
     end
end

------------------------------------------------------------------------ taşıma kafesi

do
     local ITEM = ix.item.Register("yaratik_cuval", nil, false, nil, true)
     ITEM.name = "Yakalama Çantası"
     ITEM.description = "İçi büyüyle genişletilmiş deri el çantası. Yabani bir yaratığı önce sersemlet (Stupefy, Petrificus Totalus, Arresto Momentum, Immobulus), sonra ona bakıp E'yi basılı tut; birkaç yakalamada yırtılır. Vivaryum Anahtarı'n (SYB) varsa çantayı yere bırakıp içindeki kendi vivaryumuna girersin."
     ITEM.model = A.CuvalModel
     ITEM.category = "Sihirli Yaratıklar"
     ITEM.width = 1
     ITEM.height = 1

     function ITEM:PopulateTooltip(tooltip)
          local satir = tooltip:AddRowAfter("name", "dayanim")
          satir:SetBackgroundColor(Color(120, 150, 90))
          satir:SetText("Dayanıklılık: " .. self:GetData("dayanim", A.Yabani.CantaDayanim) .. "/" .. A.Yabani.CantaDayanim)
          satir:SizeToContents()
          if self:GetData("vivAcik") then
               local acik = tooltip:AddRowAfter("dayanim", "vivAcik")
               acik:SetBackgroundColor(Color(150, 120, 70))
               acik:SetText("Şu an yerde açık (içinde biri var)")
               acik:SizeToContents()
          end
     end

     -- kişisel vivaryum (sv_9vivaryum.lua): çanta yere bırakılır, sahip içine çekilir
     ITEM.functions.vivaryum = {
          name = "Vivaryuma Gir",
          icon = "icon16/door_in.png",
          OnRun = function(item)
               if SERVER and Y.VivGir then Y.VivGir(item.player, item) end
               return false
          end,
          OnCanRun = function(item)
               if IsValid(item.entity) or item:GetData("vivAcik") then return false end
               local ply = item.player
               local char = IsValid(ply) and ply:GetCharacter()
               return char and Y.VivaryumAcik and Y.VivaryumAcik(char) and ply:GetNW2Int("SYDunya", 0) == 0 or false
          end
     }

     -- yerde açıkken (içinde biri varken) taşınamaz, atılamaz
     function ITEM:CanTransfer(eski, yeni)
          if self:GetData("vivAcik") then return false end
          return true
     end
end

do
     local ITEM = ix.item.Register("yaratik_kafes", nil, false, nil, true)
     ITEM.name = "Taşıma Kafesi"
     ITEM.description = "Bir yaratığı taşımak ya da başkasına devretmek için. Yaratık Defteri'nden 'Kafese Koy' ile doldurulur; kafesi açan karakter yaratığın yeni sahibi olur."
     ITEM.model = A.KafesModel
     ITEM.category = "Sihirli Yaratıklar"
     ITEM.width = 2
     ITEM.height = 2

     function ITEM:GetName()
          if not self:GetData("yid") then return "Boş Taşıma Kafesi" end
          return "Taşıma Kafesi: " .. self:GetData("ad", TurAd(self:GetData("tur")))
     end

     function ITEM:PopulateTooltip(tooltip)
          if not self:GetData("yid") then return end
          local n = Y.Nadirlik[self:GetData("nadir", 1)]
          local satir = tooltip:AddRowAfter("name", "yaratik")
          satir:SetBackgroundColor(n and n.renk or color_white)
          satir:SetText(TurAd(self:GetData("tur")) .. " · " .. (n and n.ad or "") .. " · " .. ((Y.Evreler[self:GetData("evre", 1)] or {}).ad or ""))
          satir:SizeToContents()
     end

     ITEM.functions.birak = {
          name = "Kafesi Aç",
          icon = "icon16/door_out.png",
          OnRun = function(item)
               if SERVER and Y.KafestenCikar then Y.KafestenCikar(item.player, item) end
               return false
          end,
          OnCanRun = function(item)
               return not IsValid(item.entity) and item:GetData("yid") ~= nil
          end
     }

     function ITEM:OnRemoved()
          if SERVER and Y.EsyaSilindi then Y.EsyaSilindi(self) end
     end
end

------------------------------------------------------------------------ yumurta

do
     local ITEM = ix.item.Register("yaratik_yumurta", nil, false, nil, true)
     ITEM.name = "Yaratık Yumurtası"
     ITEM.description = "Vivaryumdaki kuluçka yuvasına koyulunca kuluçka başlar. Sıcak tut ve düzenli çevir: kuluçkanın kalitesi yavrunun nadirliğini etkiler."
     ITEM.model = A.YumurtaModel
     ITEM.category = "Sihirli Yaratıklar"
     ITEM.width = 1
     ITEM.height = 1

     function ITEM:GetName()
          return TurAd(self:GetData("tur")) .. " Yumurtası"
     end

     function ITEM:PopulateTooltip(tooltip)
          local t = Y.Turler[self:GetData("tur")]
          if not t then return end
          local satir = tooltip:AddRowAfter("name", "sinif")
          satir:SetBackgroundColor(Color(150, 120, 80))
          satir:SetText("Tehlike: " .. Y.SinifKod(t.sinif) .. " · Kuluçka: " .. t.kulucka .. " dk")
          satir:SizeToContents()
     end

     ITEM.functions.kulucka = {
          name = "Kuluçkaya Koy",
          icon = "icon16/weather_sun.png",
          OnRun = function(item)
               if SERVER and Y.KuluckayaKoy then Y.KuluckayaKoy(item.player, item) end
               return false
          end,
          OnCanRun = function(item)
               if IsValid(item.entity) or not item:GetData("yid") then return false end
               return Y.KendiDunyasinda and Y.KendiDunyasinda(item.player) or false
          end
     }

     function ITEM:OnRemoved()
          if SERVER and Y.EsyaSilindi then Y.EsyaSilindi(self) end
     end
end
