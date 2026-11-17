-- "addons\\sardonmatbaa\\lua\\sardon_matbaa\\cl_viewer.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Basılı ürünü tam ekran gösteren görüntüleyici ("Görüntüle" ve "Karşındakine Göster").
SardonMatbaa = SardonMatbaa or {}

surface.CreateFont("SardonMatbaa.ViewTitle", { font = "Georgia", size = math.max(20, math.floor(ScrH() / 36)), weight = 700, extended = true })
surface.CreateFont("SardonMatbaa.ViewSub", { font = "Georgia", size = math.max(15, math.floor(ScrH() / 60)), weight = 400, extended = true })

local col_dim = Color(0, 0, 0, 225)
local col_paper = Color(232, 222, 198)
local col_gold = Color(214, 176, 104)
local col_text = Color(236, 226, 205)
local col_muted = Color(160, 148, 128)

function SardonMatbaa.OpenViewer(url, title, printer, shownBy)
	if IsValid(SardonMatbaa.Viewer) then SardonMatbaa.Viewer:Remove() end

	url = SardonMatbaa.ResolveImage and SardonMatbaa.ResolveImage(url) or url

	local pnl = vgui.Create("EditablePanel")
	pnl:SetSize(ScrW(), ScrH())
	pnl:MakePopup()
	pnl:SetKeyboardInputEnabled(true)
	pnl.opened = RealTime()
	SardonMatbaa.Viewer = pnl

	local sub = {}
	if printer and printer != "" then sub[#sub + 1] = "Impreso por: " .. printer end
	if shownBy and shownBy != "" then sub[#sub + 1] = shownBy .. " te lo muestra" end
	sub = table.concat(sub, "  •  ")

	function pnl:Paint(w, h)
		local a = math.Clamp((RealTime() - self.opened) / 0.15, 0, 1)

		surface.SetAlphaMultiplier(a)
		surface.SetDrawColor(col_dim)
		surface.DrawRect(0, 0, w, h)

		local top = h * 0.08
		draw.SimpleText(title or "", "SardonMatbaa.ViewTitle", w / 2, top, col_gold, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)

		if sub != "" then
			draw.SimpleText(sub, "SardonMatbaa.ViewSub", w / 2, top + 4, col_muted, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
		end

		local mat, state = SardonMatbaa.GetMaterial(url)
		local bx, by, bw, bh = w * 0.1, h * 0.14, w * 0.8, h * 0.76

		if mat then
			local iw, ih = mat:Width(), mat:Height()
			local s = math.min(bw / iw, bh / ih)
			local dw, dh = iw * s, ih * s
			local x, y = bx + (bw - dw) / 2, by + (bh - dh) / 2

			surface.SetDrawColor(col_paper)
			surface.DrawRect(x - 10, y - 10, dw + 20, dh + 20)
			SardonMatbaa.DrawFit(mat, x, y, dw, dh)
		else
			draw.SimpleText(state == "fail" and "No se pudo cargar la imagen." or "Cargando imagen...", "SardonMatbaa.ViewSub", w / 2, h / 2, col_text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end

		draw.SimpleText("Clic o ESC para cerrar", "SardonMatbaa.ViewSub", w / 2, h - 16, col_muted, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
		surface.SetAlphaMultiplier(1)
	end

	function pnl:OnMousePressed()
		if RealTime() - self.opened > 0.2 then self:Remove() end
	end

	function pnl:OnKeyCodePressed(key)
		if key == KEY_ESCAPE or key == KEY_E or key == KEY_SPACE then self:Remove() end
	end

	function pnl:Think()
		if input.IsKeyDown(KEY_ESCAPE) then
			gui.HideGameUI()
			self:Remove()
		end
	end
end

net.Receive("SardonMatbaa.View", function()
	local url = net.ReadString()
	local title = net.ReadString()
	local printer = net.ReadString()
	local shownBy = net.ReadString()

	SardonMatbaa.OpenViewer(url, title, printer, shownBy)
end)
