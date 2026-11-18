-- "addons\\sardongorev\\lua\\weapons\\gmod_tool\\stools\\sardon_gorev.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
/*
*   Görev aracı: haritaya görev yerleri koymak ve yol çizmek için.
*   Sol tık: baktığın yere yeni yer (yol çiziliyorsa nokta ekler)
*   Sağ tık: yakındaki yeri seç (yol çiziliyorsa son noktayı siler)
*   R: Görev Atölyesi. İşlemler sunucuda görev editörü yetkisiyle doğrulanır.
*/
TOOL.Category = "Sardon"
TOOL.Name = "#tool.sardon_gorev.name"

TOOL.Information = {
     { name = "left" },
     { name = "right" },
     { name = "reload" },
}

local function G() return SardonGorev end

function TOOL:LeftClick(iz)
     if CLIENT and IsFirstTimePredicted() and G() and G().AracSol then G().AracSol(iz) end
     return false
end

function TOOL:RightClick(iz)
     if CLIENT and IsFirstTimePredicted() and G() and G().AracSag then G().AracSag(iz) end
     return false
end

function TOOL:Reload()
     if CLIENT and IsFirstTimePredicted() and G() and G().EditorAc then G().EditorAc() end
     return false
end

if CLIENT then
     language.Add("tool.sardon_gorev.name", "Lugares de misión")
     language.Add("tool.sardon_gorev.desc", "Coloca lugares, rutas y puntos de cámara para el sistema de misiones")
     language.Add("tool.sardon_gorev.left", "Colocar lugar donde miras (si dibujas ruta: añadir punto)")
     language.Add("tool.sardon_gorev.right", "Seleccionar lugar cercano (si dibujas ruta: borrar último punto)")
     language.Add("tool.sardon_gorev.reload", "Abrir Taller de misiones")

     function TOOL:DrawHUD()
          local S = G()
          if not S or not S.R then return end
          local O, F = S.O, S.F
          local w, h = O(300), O(96)
          local x, y = ScrW() - w - O(24), ScrH() / 2 - h / 2
          S.Pano(x, y, w, h, 1)
          S.Yaz("LUGARES DE MISIÓN", F(12, "kalin"), x + O(16), y + O(20), S.R.altin, 0, O(3))
          local yol = S.YolDuzenlenen
          S.Yaz(yol and ("Dibujando ruta: " .. yol) or "Clic izq.: nuevo lugar", F(15, "kalin"), x + O(16), y + O(48), S.R.fildisi)
          S.Yaz(yol and (#((S.E.yerler[yol] or {}).noktalar or {}) .. " puntos · clic der.: borrar último") or "Clic der.: elegir lugar · R: taller", F(12, "govde"), x + O(16), y + O(72), S.R.soluk)
     end

     function TOOL.BuildCPanel(panel)
          panel:Help("Lugares del sistema de misiones: las misiones referencian estos lugares por nombre.")
          panel:Help("Clic izq.: nuevo lugar · Clic der.: abrir cercano · R: Taller de misiones")
          panel:Button("Abrir Taller de misiones", "sardon_gorev_editor")
     end
end
