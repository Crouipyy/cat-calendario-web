-- "addons\\sardonekonomi\\lua\\sardon_ekonomi\\sh_9makbuz.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- [sardon] ekonomi: Gringotts Takas Makbuzu (masa takası ve emanet sözleşmesi sonunda iki tarafa verilir).
-- Veri: no, tarih, a, b, aKalem {..}, bKalem {..}, aPara, bPara, ucret, tur ("takas"|"emanet"), notu
local ITEM = ix.item.Register("ekonomi_makbuz", nil, false, nil, true)
ITEM.name = "Gringotts Takas Makbuzu"
ITEM.description = "Goblin noterin mühürlediği takas belgesi. Kimin neyi, ne zaman verdiğini kanıtlar."
ITEM.model = "models/props_c17/paper01.mdl"
ITEM.category = "Belgeler"
ITEM.width = 1
ITEM.height = 1

function ITEM:GetName()
     return "Gringotts Makbuzu " .. (self:GetData("no") or "")
end

function ITEM:PopulateTooltip(tooltip)
     local satir = tooltip:AddRowAfter("name", "makbuz")
     satir:SetBackgroundColor(Color(150, 120, 60))
     satir:SetText(os.date("%d.%m.%Y %H:%M", self:GetData("tarih", 0)) .. " · " .. (self:GetData("a") or "?") .. " ↔ " .. (self:GetData("b") or "?"))
     satir:SizeToContents()
end

ITEM.functions.Oku = {
     name = "Oku",
     icon = "icon16/page_white_text.png",
     OnRun = function(item)
          if SERVER and IsValid(item.player) then
               net.Start("SardonEko.Makbuz")
                    net.WriteTable(item.data or {})
               net.Send(item.player)
          end
          return false
     end,
}

if SERVER then util.AddNetworkString("SardonEko.Makbuz") end
