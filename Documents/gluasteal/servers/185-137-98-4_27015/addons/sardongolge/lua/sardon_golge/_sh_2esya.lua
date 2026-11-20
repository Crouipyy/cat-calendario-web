-- "addons\\sardongolge\\lua\\sardon_golge\\_sh_2esya.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Gölge :: Helix eşyası "Gerçeklik Hançeri". Helix eşyaları üst üste yığılmadığı için sayı eşyanın "adet"
-- verisinde; yeni alınan hançer var olanın sayısına eklenir, "Bir tane ayır" tek hançerlik yeni eşya açar (takas için).
local S = SardonGolge

local ITEM = ix.item.Register(S.ESYA, nil, false, nil, true)
ITEM.name = "Gerçeklik Hançeri"
ITEM.description = "Kara bir kabza, ince ve soğuk bir namlu."
ITEM.model = "models/weapons/w_knife_t.mdl"
ITEM.width = 1
ITEM.height = 1
ITEM.category = "Karaborsa"
ITEM.noBusiness = true

function ITEM:GetAdet()
     return math.max(1, math.floor(tonumber(self:GetData("adet", 1)) or 1))
end

function ITEM:GetName()
     local n = self:GetAdet()
     return n > 1 and ("Gerçeklik Hançeri (" .. n .. ")") or "Gerçeklik Hançeri"
end

function ITEM:GetDescription()
     return "Kara bir kabza, ince ve soğuk bir namlu. Saplandığı kişinin görünüşünü içine çeker; sahibi o görünüşe bürünebilir."
          .. "\nKalan: " .. self:GetAdet()
          .. "\nEline al: sol tık karşındakine saplar, sağ tık kılık menüsünü açar."
end

if CLIENT then
     function ITEM:PaintOver(item, w, h)
          local n = item.GetAdet and item:GetAdet() or 1
          if n > 1 then draw.SimpleTextOutlined(n, "DermaDefaultBold", w - 4, h - 4, color_white, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM, 1, color_black) end
     end
end

ITEM.functions.EleAl = {
     name = "Eline Al",
     icon = "icon16/bullet_black.png",
     OnRun = function(item)
          local ply = item.player
          if SERVER and IsValid(ply) and ply:Alive() then
               if not ply:HasWeapon(S.SILAH) then ply:Give(S.SILAH) end
               ply:SelectWeapon(S.SILAH)
          end
          return false
     end,
     OnCanRun = function(item)
          return not IsValid(item.entity) and IsValid(item.player) and item.player:Alive()
     end
}

ITEM.functions.Ayir = {
     name = "Bir tane ayır",
     icon = "icon16/arrow_divide.png",
     OnRun = function(item)
          if SERVER and S.HancerAyir then S.HancerAyir(item) end
          return false
     end,
     OnCanRun = function(item)
          return not IsValid(item.entity) and item:GetAdet() > 1
     end
}
