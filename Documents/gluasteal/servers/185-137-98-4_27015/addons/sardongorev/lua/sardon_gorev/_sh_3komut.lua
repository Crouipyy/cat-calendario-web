-- "addons\\sardongorev\\lua\\sardon_gorev\\_sh_3komut.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
/*
*   Sohbet komutları ve [mac] simple-npcs (MCS) uyumu.
*   MCS diyaloglarında eski "MQS Continue quest" cevapları artık bu sistemde
*   "mcs_<npc kimliği>" olayını tetikler (Olay bekle hedefi ya da olayla başlayan görev).
*/
local G = SardonGorev

if ix and ix.command then
     ix.command.Add("Gorevler", {
          description = "Abre el diario de misiones.",
          OnRun = function(_, ply) ply:ConCommand("sardon_gorev_gunluk") end,
     })
     ix.command.Add("GorevEditor", {
          description = "Abre el Taller de misiones (editor).",
          OnCheckAccess = function(_, ply) return G.Editor(ply) end,
          OnRun = function(_, ply) ply:ConCommand("sardon_gorev_editor") end,
     })
end

local function MCSBagla()
     if not MCS or not MCS.AddonList then return end
     local function Olay(ply, npc)
          if not SERVER or not IsValid(ply) or not G.Tetikle then return end
          local uid = IsValid(npc) and npc.GetUID and npc:GetUID() or ""
          G.Tetikle(ply, "mcs_" .. tostring(uid))
          G.Tetikle(ply, "mcs_devam")
     end
     MCS.AddonList["Görev: Devam"] = { check = function() return true end, ["function_sv"] = Olay, enabled = true }
     -- eski MQS cevapları (MQS kaldırıldı)
     MCS.AddonList["MQS Continue quest"] = { check = function() return true end, ["function_sv"] = Olay, enabled = true }
end
MCSBagla()
timer.Simple(5, MCSBagla)
