-- "addons\\sardoncigirtkan\\lua\\sardon_cigirtkan\\sh_item.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Boş Çığırtkan: tek kullanımlık kırmızı zarf. Gönderirken harcanır, teslim edilemezse geri verilir.
-- Satış: Evcil Baykuş Mağazası > "Çığırtkan" sekmesi (sardon_shopic, "SardonShopKur" kancası).
local C = SardonCigirtkan

-- Canlı yeniden yüklemede envanterdeki eşyalar ESKİ sınıf tablosunu tutar; tablo varsa yerinde güncellenir.
local ITEM = ix.item.list[C.ITEM] or ix.item.Register(C.ITEM, nil, false, nil, true)

ITEM.name = "Vociferador"
ITEM.description = "Un sobre rojo sin sellar. Lo que digas dentro se grita al destinatario cien veces más alto; luego el sobre se quema.\n\nPara enviar: en TAB haz clic en un jugador > \"Enviar vociferador\". Tu lechuza lo lleva.\nSi tienes autoridad (profesor, prefecto...) también puedes enviarlo a una casa o grupo: clic derecho > \"Envío masivo\" o /TopluCigirtkan."
ITEM.model = "models/props_c17/paper01.mdl"
ITEM.width = 1
ITEM.height = 1
ITEM.category = "Correo de lechuzas"
ITEM.noBusiness = true

-- Toplu gönderim yetkisi sunucuda hesaplanır, oyuncuya NW2 bayrağıyla bildirilir (sv_3ucus)
ITEM.functions.topluGonder = {
     name = "Envío masivo",
     icon = "icon16/group.png",
     OnClick = function(item)
          net.Start("SardonCigirtkan.TopluListe")
          net.SendToServer()
          return false
     end,
     OnRun = function() return false end,
     OnCanRun = function(item)
          local ply = item.player or item:GetOwner()
          return not IsValid(item.entity) and IsValid(ply) and ply:GetNW2Bool("SardonCigirtkanToplu", false)
     end
}

ix.command.Add("TopluCigirtkan", {
     description = "Envía un vociferador masivo a una casa o grupo si tienes autoridad.",
     OnRun = function(self, client)
          if C.TopluListeYolla then C.TopluListeYolla(client) end
     end
})

function ITEM:OnEntityCreated(entity)
     entity:SetMaterial("models/debug/debugwhite")
     entity:SetColor(Color(150, 22, 28))
end

if CLIENT then
     -- Solo el sobre: no rellenar el slot (antes un rect opaco lo dejaba negro).
     function ITEM.PaintOver(panel, item, w, h)
          if C.ZarfCiz2D then
               C.ZarfCiz2D(w * 0.12, h * 0.22, w * 0.76, h * 0.56, 0, 0)
          end
     end
end

----------------------------------------------------------------------------------------
-- Satıcı
----------------------------------------------------------------------------------------
local function Alabilir(ply)
     local char = ply:GetCharacter()
     if not char then return false end
     if not char:GetInventory():FindEmptySlot(1, 1, true) then return "No hay sitio en el inventario" end
     return true
end

local function Ver(ply)
     local char = ply:GetCharacter()
     if not char then return end
     if not char:GetInventory():Add(C.ITEM) then
          ix.item.Spawn(C.ITEM, ply:GetItemDropPos())
     end
     ply:Notify("Has recibido un vociferador. En TAB haz clic en un jugador y elige \"Enviar vociferador\".")
end

local function Simge()
     local p = vgui.Create("Panel")
     function p:Paint(w, h)
          surface.SetDrawColor(150, 22, 28, 60)
          surface.DrawRect(0, 0, w, h)
          if C.ZarfCiz2D then
               local t = CurTime()
               C.ZarfCiz2D(w * 0.18, h * 0.3, w * 0.64, h * 0.42, (math.sin(t * 3) * 0.5 + 0.5) * 0.35, 0.3)
          end
     end
     return p
end

function C.DukkanKur(shops)
     local s = istable(shops) and shops.baykusstore
     if not s or not istable(s.tabs) then return end

     -- Mağaza sekmeleri SortedPairsByMemberValue(..., "order") ile dizilir: sırası olmayan sekme
     -- (ör. "Baykuşlar") ikinci bir sekmenin yanında nil karşılaştırma hatası verir.
     for _, tab in pairs(s.tabs) do
          if istable(tab) and tab.order == nil then tab.order = 1 end
     end

     s.tabs["Aullador"] = nil
     s.tabs["Vociferador"] = {
          order = 2,
          desc = "Graba tu voz; la lechuza gritará al destinatario",
          icon = "2NGmHP4",
          colors = {Color(150, 22, 28), Color(214, 64, 52)},
          items = {
               {
                    name = "Vociferador",
                    price = C.Ayar.Fiyat,
                    OnBuy = Ver,
                    CanBuy = Alabilir,
                    BuildIcon = Simge
               }
          }
     }
end

hook.Add("SardonShopKur", "SardonCigirtkan", C.DukkanKur)

if SardonShop and SardonShop.Shops then
     C.DukkanKur(SardonShop.Shops)
end
