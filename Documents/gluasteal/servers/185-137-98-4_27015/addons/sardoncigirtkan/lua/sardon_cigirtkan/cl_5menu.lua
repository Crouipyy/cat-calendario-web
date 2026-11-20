-- "addons\\sardoncigirtkan\\lua\\sardon_cigirtkan\\cl_5menu.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Çığırtkan :: istemci — TAB menüsünde oyuncuya "Çığırtkan Gönder" (baykuş mektubunun yanında).
-- Asıl denetim sunucudadır; burada yalnızca seçeneğin görünüp görünmeyeceğine bakılır.
local C = SardonCigirtkan

hook.Add("PopulateScoreboardPlayerMenu", "SardonCigirtkan", function(hedef, menu)
     local lp = LocalPlayer()
     local char = lp:GetCharacter()
     if not char or not IsValid(hedef) or hedef == lp then return end

     local hc = hedef:GetCharacter()
     if not hc then return end
     if not (char:DoesRecognize(hc) or hook.Run("IsPlayerRecognized", hedef)) then return end

     local inv = char:GetInventory()
     if not inv or not inv:HasItem(C.ITEM) or not inv:HasItem("PetOwl") then return end

     menu:AddOption("Enviar vociferador", function()
          net.Start("SardonCigirtkan.Basla")
               net.WriteEntity(hedef)
               net.WriteString("")
          net.SendToServer()
          if IsValid(ix.gui.menu) then ix.gui.menu:Remove() end
     end)
end)
