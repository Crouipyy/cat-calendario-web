-- "addons\\sardonkitap\\lua\\sardon_kitap\\_sh_4esya.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Kitap :: Helix eşyaları — kitap_<id> (her kitap 1×1), kitap_kayisi (yalnız kitap alan 4×2 çanta),
-- hogwarts_mektubu, okul_kazani.
-- Kitap verisi: seri (kenar notları bu numaraya bağlı, ikinci elde değişmez), sahip, charid, hane,
-- tarih, onceki = {"ad", ...} (ikinci el geçmişi).

local SK = SardonKitap

if not (ix and ix.item) then return end

local function Kayit(uid, taban)
     -- canlı yenilemede envanterdeki eşyalar eski sınıf tablosunu tutar; varsa yerinde güncellenir
     return ix.item.list[uid] or ix.item.Register(uid, taban, false, nil, true)
end

local function EnvanterdeMi(item) return not IsValid(item.entity) end

for _, k in ipairs(SK.KITAPLAR) do
     local ITEM = Kayit(SK.EsyaId(k.id))
     ITEM.name = k.ad
     ITEM.description = k.ozet
     ITEM.model = k.model
     ITEM.width = 1
     ITEM.height = 1
     ITEM.category = "Okul Kitapları"
     ITEM.noBusiness = true
     ITEM.sardonKitap = k.id

     function ITEM:GetName()
          return k.ad
     end

     function ITEM:GetDescription()
          local t = {k.en, k.yazar, "", k.ozet}
          local sahip = self:GetData("sahip")
          if sahip then
               local hane = self:GetData("hane")
               t[#t + 1] = ""
               t[#t + 1] = "Sahibi: " .. sahip .. (hane and (" · " .. hane) or "")
          end
          local onceki = self:GetData("onceki")
          if istable(onceki) and #onceki > 0 then
               t[#t + 1] = "İkinci el · önceki sahipleri: " .. table.concat(onceki, ", ")
          end
          return table.concat(t, "\n")
     end

     ITEM.functions.sardonOku = {
          name = "Oku",
          icon = "icon16/book_open.png",
          OnRun = function(item)
               if SERVER and SK.KitapAc then SK.KitapAc(item.player, k.id, item) end
               return false
          end,
          OnCanRun = EnvanterdeMi
     }
end

do
     local ITEM = Kayit(SK.KAYIS, "base_bags")
     ITEM.name = "Kitap Kayışı"
     ITEM.description = "Pirinç tokalı deri kayış. Sekiz ders kitabını bir arada taşır; içine yalnızca kitap konabilir."
     ITEM.model = SK.KAYIS_MODEL
     ITEM.width = 2
     ITEM.height = 1
     ITEM.invWidth = SK.KAYIS_W
     ITEM.invHeight = SK.KAYIS_H
     ITEM.category = "Okul Kitapları"
     ITEM.noBusiness = true
     -- Register, OnRegistered'ı alanlar atanmadan çağırır (taban 6×6); boyutu yeniden kaydet
     if ix.inventory and ix.inventory.Register then
          ix.inventory.Register(SK.KAYIS, SK.KAYIS_W, SK.KAYIS_H, true)
     end
end

-- kayışa yalnız kitap girer (sunucu Transfer'de sorar)
hook.Add("CanTransferItem", "SardonKitap.Kayis", function(item, eski, yeni)
     if not yeni or not yeni.vars or yeni.vars.isBag ~= SK.KAYIS then return end
     if not SK.EsyadanKitap(item.uniqueID) then return false end
end)

do
     local ITEM = Kayit(SK.MEKTUP)
     ITEM.name = "Hogwarts Mektubu"
     ITEM.description = "Zümrüt yeşili mürekkeple yazılmış adres, mor mumlu bir mühür. İçinde okul malzemelerinin listesi var."
     ITEM.model = "models/items/magic/scrolls/scroll_rolled.mdl"
     ITEM.width = 1
     ITEM.height = 1
     ITEM.category = "Okul Kitapları"
     ITEM.noBusiness = true

     function ITEM:GetName()
          local y = tonumber(self:GetData("yil", 1)) or 1
          return y > 1 and ("Hogwarts Mektubu · " .. y .. ". Yıl") or "Hogwarts Mektubu"
     end

     ITEM.functions.sardonMektup = {
          name = "Oku",
          icon = "icon16/email_open.png",
          OnRun = function(item)
               if SERVER and SK.MektupAc then SK.MektupAc(item.player, tonumber(item:GetData("yil", 1)) or 1) end
               return false
          end,
          OnCanRun = EnvanterdeMi
     }
end

do
     -- Nadirlikli kazan (11-06): veride kademe 1..6 (Kalay → Platin), yoksa Kalay. Tanımlar ve
     -- istatistikler [sardon] iksir potion_zkazan/_sh_1kademe.lua (SardonIksir), çalışma anında okunur.
     local function Iksir() return SardonIksir and SardonIksir.KazanTanim and SardonIksir end

     local ITEM = Kayit(SK.KAZAN)
     ITEM.name = "Kalay Kazan"
     -- Sanctuary modelinin sınırları animasyonlar yüzünden çok büyük (z -89..107): Helix'in kendi ikon kamerası
     -- kazanı minicik çiziyordu (11-06, TAB envanter). Kamera elle; altı kademe modeli aynı boyda.
     -- 42° fazla geniş çıktı (kazan hücrenin üçte biri); 19° oyunda denendi, dört kademe hücreyi dolduruyor
     ITEM.iconCam = {pos = Vector(58, 42, 40), ang = Angle(23.4, 215.5, 0), fov = 19}

     -- Helix'in spawn ikonu 84 px envanter hücresinde yine minicik kalıyordu (önbellek boyut kademesi; 128 px
     -- denemede doğruydu): bu eşyanın ikonu kendi kameramızla her çizimde canlı çizilir (DModelPanel gibi),
     -- önbellekli resim yalnız bu panelde gizlenir. Kademe modeli GetModel'den.
     if CLIENT then
          local modeller = {}
          local IKON_FOV = 16
          local function IkonModeli(mdl)
               local m = modeller[mdl]
               if IsValid(m) then return m end
               m = ClientsideModel(mdl, RENDERGROUP_OPAQUE)
               if not IsValid(m) then return nil end
               m:SetNoDraw(true)
               m:SetPos(vector_origin)
               m:SetAngles(angle_zero)
               modeller[mdl] = m
               return m
          end

          -- menü solarken ikon da solsun (cam.Start3D panel alfasını almaz, 11-06)
          local function EtkinAlfa(p)
               local a = 1
               while IsValid(p) do
                    a = a * p:GetAlpha() / 255
                    p = p:GetParent()
               end
               return a
          end

          -- Helix: itemTable.PaintOver(panel, itemTable, w, h)
          function ITEM.PaintOver(panel, item, w, h)
               local m = IkonModeli(item:GetModel())
               if not IsValid(m) then return end
               local alfa = EtkinAlfa(panel)
               if IsValid(panel.Icon) and panel.Icon:IsVisible() then panel.Icon:SetVisible(false) end
               local c = item.iconCam
               local x, y = panel:LocalToScreen(0, 0)
               cam.Start3D(c.pos, c.ang, IKON_FOV, x, y, w, h, 5, 1000)
                    render.SuppressEngineLighting(true)
                    render.SetLightingOrigin(vector_origin)
                    render.ResetModelLighting(0.4, 0.4, 0.4)
                    render.SetModelLighting(BOX_TOP, 1, 1, 1)
                    render.SetModelLighting(BOX_FRONT, 0.8, 0.8, 0.8)
                    render.SetColorModulation(1, 1, 1)
                    render.SetBlend(alfa)
                    if alfa > 0.01 then m:DrawModel() end
                    render.SetBlend(1)
                    render.SuppressEngineLighting(false)
               cam.End3D()
          end
     end
     ITEM.description = "Kalaylı, standart boy 2. Yere kurup iksir kaynatabilirsin; yalnızca sen kullanabilirsin."
     ITEM.model = SK.KAZAN_MODEL
     ITEM.width = 2
     ITEM.height = 2
     ITEM.category = "Okul Kitapları"
     ITEM.noBusiness = true

     function ITEM:GetName()
          local I = Iksir()
          return I and I.KazanAdi(I.EsyaKademe(self)) or self.name
     end

     function ITEM:GetModel()
          local I = Iksir()
          return I and I.KazanTanim(I.EsyaKademe(self)).model or self.model
     end

     function ITEM:GetDescription()
          local I = Iksir()
          if not I then return self.description end
          local k = I.EsyaKademe(self)
          local t = I.KazanTanim(k)
          local s = {t.nadir .. " kazan. Yere kurup iksir kaynatabilirsin; yalnızca sen kullanabilirsin."}
          for _, satir in ipairs(I.KazanOzet(k)) do s[#s + 1] = satir[1] .. ": " .. satir[2] end
          if k < I.KAZAN_EN_UST then s[#s + 1] = "Bay Arthur " .. I.YukseltBedel(k) .. " Galleon'a " .. I.KazanTanim(k + 1).ad .. " yapar." end
          return table.concat(s, "\n")
     end

     ITEM.functions.sardonKazanKur = {
          name = "Kazanı Kur",
          icon = "icon16/arrow_down.png",
          OnRun = function(item)
               if SERVER and SK.KazanKur then SK.KazanKur(item.player, item) end
               return false
          end,
          OnCanRun = EnvanterdeMi
     }

     ITEM.functions.sardonKazanTopla = {
          name = "Kazanı Topla",
          icon = "icon16/arrow_up.png",
          OnRun = function(item)
               if SERVER and SK.KazanTopla then SK.KazanTopla(item.player) end
               return false
          end,
          OnCanRun = EnvanterdeMi
     }
end
