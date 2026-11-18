-- "addons\\sardonbaykus\\lua\\sardon_baykus\\sh_bohca.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Baykuş Eşya Bohçası: baykuşla mesajın yanında en fazla 5 eşya + Galleon göndermek için.
--
-- Bohça gerçek bir Helix çantası (base_bags): envanterde "Aç" ile açılıp eşyalar
-- sürükle-bırak ile konuluyor. Sadece admin whitelist'indeki eşyalar ve en fazla
-- "maxItems" (varsayılan 5) eşya girebiliyor (bkz. sv_bohca.lua, CanTransferItem).
-- Galleon bohçanın verisinde ("money") duruyor: "Galleon Koy" / "Galleon Topla".
--
-- Baykuşla giderken bohça item'ı (içindeki çanta envanteriyle birlikte) "mantıksal
-- olarak" dünyaya alınıyor (entity doğmadan, invID 0) ve teslimde alıcının envanterine
-- aktarılıyor -- içindeki eşyalar hiç silinip yeniden yaratılmıyor.
SardonBaykus = SardonBaykus or {}

SardonBaykus.BohcaID = "baykus_bohca"
SardonBaykus.BohcaModel = "models/items/jewels/purses/very_big_purse.mdl"
SardonBaykus.MaxItemsHard = 5

-- Bohçaya ne olursa olsun (whitelist'te olsa bile) konulamayacak item türleri.
function SardonBaykus.IsHardBlocked(itemTable)
     if (!itemTable) then
          return true, "Objeto inválido"
     end

     if (itemTable.uniqueID == SardonBaykus.BohcaID) then
          return true, "No se puede meter una bolsa dentro de otra"
     end

     if (itemTable.isBag or itemTable.base == "base_bags" or itemTable.base == "base_backpack" or itemTable.invWidth) then
          return true, "No se pueden meter mochilas en la bolsa"
     end

     if (itemTable.base == "PetBase") then
          return true, "No se pueden meter mascotas en la bolsa"
     end

     return false
end

-- Bohçanın çanta envanterindeki eşyalar (istemcide de çalışır -- sahibine senkron).
function SardonBaykus.GetBohcaItems(bohca)
     local inventory = bohca.GetInventory and bohca:GetInventory()
     local items = {}

     if (inventory) then
          for _, item in pairs(inventory:GetItems()) do
               table.insert(items, item)
          end

          table.sort(items, function(a, b) return a.id < b.id end)
     end

     return items
end

function SardonBaykus.GetBohcaMoney(bohca)
     return bohca:GetData("money", 0)
end

function SardonBaykus.IsBohcaEmpty(bohca)
     return #SardonBaykus.GetBohcaItems(bohca) == 0 and SardonBaykus.GetBohcaMoney(bohca) <= 0
end

local function ItemName(item)
     local name = item.GetName and item:GetName() or item.name or item.uniqueID or "?"

     return (CLIENT and L) and L(name) or name
end

-- "Asa x1, Kitap x2, 50 Galleon" gibi özet parçaları.
function SardonBaykus.SummarizeBohca(bohca)
     local counts, order = {}, {}

     for _, item in ipairs(SardonBaykus.GetBohcaItems(bohca)) do
          local name = ItemName(item)

          if (!counts[name]) then
               counts[name] = 0
               table.insert(order, name)
          end

          counts[name] = counts[name] + 1
     end

     local parts = {}

     for _, name in ipairs(order) do
          table.insert(parts, name .. " x" .. counts[name])
     end

     local money = SardonBaykus.GetBohcaMoney(bohca)

     if (money > 0) then
          table.insert(parts, money .. " Galleon")
     end

     return parts
end

do
     local ITEM = ix.item.Register(SardonBaykus.BohcaID, "base_bags", false, nil, true)

     ITEM.name = "Bolsa de objetos"
     ITEM.description = "Un saquito que te permite enviar hasta 5 objetos y Galleons junto con tu lechuza. No olvides seleccionar la bolsa al enviar."
     ITEM.model = SardonBaykus.BohcaModel
     ITEM.category = "Lechuza"
     ITEM.width = 1
     ITEM.height = 1
     -- 5x2: iki kare yüksekliğindeki eşyalar da sığsın; eşya SAYISI ayrıca 5 ile sınırlı.
     ITEM.invWidth = 5
     ITEM.invHeight = 2

     -- base_bags'in OnRegistered'ı Register sırasında temel boyutlarla (6x6) çalıştı --
     -- envanter türünü kendi boyutumuzla yeniden kaydediyoruz.
     ix.inventory.Register(SardonBaykus.BohcaID, ITEM.invWidth, ITEM.invHeight, true)

     function ITEM:GetName()
          local count = #SardonBaykus.GetBohcaItems(self)

          return "Bolsa de objetos" .. ((count > 0 or SardonBaykus.GetBohcaMoney(self) > 0) and (" (" .. count .. "/" .. SardonBaykus.MaxItemsHard .. ")") or "")
     end

     ITEM.functions.bohcaGalleonKoy = {
          name = "Depositar Galleons",
          icon = "icon16/coins_add.png",
          OnClick = function(item)
               local itemID = item.id
               local invID = item.invID

               Derma_StringRequest("Depositar Galleons", "¿Cuántos Galleons quieres meter en la bolsa?", "", function(text)
                    local amount = math.floor(tonumber(text) or 0)

                    if (amount > 0) then
                         net.Start("ixInventoryAction")
                              net.WriteString("bohcaGalleonKoy")
                              net.WriteUInt(itemID, 32)
                              net.WriteUInt(invID, 32)
                              net.WriteTable({amount})
                         net.SendToServer()
                    end
               end)

               return false
          end,
          OnRun = function(item, data)
               if (SERVER and SardonBaykus.PutMoney) then
                    SardonBaykus.PutMoney(item.player, item, math.floor(tonumber(istable(data) and data[1]) or 0))
               end

               return false
          end,
          OnCanRun = function(item)
               return !IsValid(item.entity)
          end
     }

     ITEM.functions.bohcaGalleonTopla = {
          name = "Retirar Galleons",
          icon = "icon16/coins_delete.png",
          OnRun = function(item)
               if (SERVER and SardonBaykus.TakeMoney) then
                    SardonBaykus.TakeMoney(item.player, item)
               end

               return false
          end,
          OnCanRun = function(item)
               return !IsValid(item.entity) and SardonBaykus.GetBohcaMoney(item) > 0
          end
     }

     ITEM.functions.bohcaHepsiniTopla = {
          name = "Recoger todo",
          icon = "icon16/basket_remove.png",
          OnRun = function(item)
               if (SERVER and SardonBaykus.CollectAll) then
                    SardonBaykus.CollectAll(item.player, item)
               end

               return false
          end,
          OnCanRun = function(item)
               return !IsValid(item.entity) and !SardonBaykus.IsBohcaEmpty(item)
          end
     }

     if (CLIENT) then
          function ITEM:PopulateTooltip(tooltip)
               local from = self:GetData("from")

               if (from) then
                    local row = tooltip:AddRow("bohcaFrom")
                    row:SetText("Remitente: " .. from)
                    row:SetBackgroundColor(Color(120, 90, 40))
                    row:SizeToContents()
               end

               local parts = SardonBaykus.SummarizeBohca(self)
               local row = tooltip:AddRow("bohcaContents")
               row:SetText(#parts > 0 and ("Contenido: " .. table.concat(parts, ", ")) or "Bolsa vacía")
               row:SizeToContents()
          end

          -- base_bags'in PaintOver'ı (açık çanta penceresini vurgulama) korunuyor, üstüne
          -- sağ altta Galleon rozeti ekleniyor.
          -- Doğrudan baz tablodan (ITEM.PaintOver canlı yenilemede bizim eski fonksiyonumuz olabilir).
          local basePaintOver = ix.item.base.base_bags and ix.item.base.base_bags.PaintOver
          local col_badge = Color(0, 0, 0, 190)
          local col_badgeText = Color(255, 210, 120)

          function ITEM:PaintOver(item, w, h)
               if (basePaintOver) then
                    basePaintOver(self, item, w, h)
               end

               local money = SardonBaykus.GetBohcaMoney(item)

               if (money <= 0) then
                    return
               end

               local text = money .. " G"

               surface.SetFont("DermaDefaultBold")
               local tw = surface.GetTextSize(text)

               draw.RoundedBox(4, w - tw - 10, h - 18, tw + 8, 16, col_badge)
               draw.SimpleText(text, "DermaDefaultBold", w - 6, h - 10, col_badgeText, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
          end
     end
end

-- ============= ESKİ BOHÇA ÖRNEKLERİNİ GÜNCELLE =============
-- ix.item.Register bir bazla (base_bags) kayıt yaparken YENİ bir sınıf tablosu üretiyor;
-- dosya canlı yenilenince (gluapack autorefresh) ya da bohçanın çanta olmadığı ilk sürümden
-- kalan örnekler hâlâ ESKİ sınıf tablosuna bakıyordu -- isBag = true ama functions.View
-- yok -> Helix envanter sekmesi (cl_inventory.lua:782 "openBags") çöküyordu. Mevcut
-- örnekleri güncel sınıfa eşitliyoruz; sunucuda çanta envanteri olmayanlara envanter
-- açılıyor, ilk sürümün veri içindeki eşyaları ("contents") sahibine geri veriliyor.
do
     local class = ix.item.list[SardonBaykus.BohcaID]

     -- Örneğe ait durum -- sınıftan asla üzerine yazılmamalı.
     local INSTANCE_KEYS = {id = true, data = true, invID = true, gridX = true, gridY = true, entity = true, player = true, characterID = true, playerID = true}

     for _, item in pairs(ix.item.instances) do
          if (item.uniqueID == SardonBaykus.BohcaID and class) then
               for key, value in pairs(class) do
                    if (!INSTANCE_KEYS[key]) then
                         item[key] = value
                    end
               end

               if (SERVER and !item:GetData("id")) then
                    local inventory = ix.item.inventories[item.invID]
                    local ownerChar = inventory and inventory.owner or 0

                    ix.inventory.New(ownerChar, SardonBaykus.BohcaID, function(inv)
                         inv.vars.isBag = SardonBaykus.BohcaID
                         item:SetData("id", inv:GetID())

                         local owner = inv:GetOwner()

                         if (IsValid(owner)) then
                              inv:Sync(owner)
                              inv:AddReceiver(owner)
                         end

                         -- İlk sürümün veri tabanlı içeriği: sahibinin envanterine iade.
                         local oldContents = item:GetData("contents")
                         local mainInv = IsValid(owner) and owner:GetCharacter() and owner:GetCharacter():GetInventory()

                         if (istable(oldContents) and #oldContents > 0 and mainInv) then
                              for _, entry in ipairs(oldContents) do
                                   if (ix.item.list[entry.uniqueID] and !mainInv:Add(entry.uniqueID, 1, entry.data)) then
                                        ix.item.Spawn(entry.uniqueID, owner:GetItemDropPos(), nil, angle_zero, entry.data)
                                   end
                              end
                         end

                         if (oldContents != nil) then
                              item:SetData("contents", nil)
                         end
                    end)
               end
          end
     end
end

-- /baykus_admin -- yönetim paneli (bkz. sv_admin.lua / cl_admin.lua). Komut paylaşımlı
-- kayıtlı olmalı ki istemcinin sohbet kutusu da tanısın; asıl iş sunucuda.
ix.command.Add("baykus_admin", {
     description = "Abre el panel de administración del sistema de lechuzas.",
     adminOnly = true,
     OnRun = function(self, client)
          if (SERVER and SardonBaykus.SendAdminData) then
               SardonBaykus.SendAdminData(client, true)
          end
     end
})
