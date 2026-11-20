-- Sardon Ekonomi :: intercambio seguro (cliente)
SardonEkonomi = SardonEkonomi or {}
local E = SardonEkonomi

local R = {
	zemin = Color(24, 19, 15, 248), kart = Color(38, 31, 25, 255), secili = Color(70, 92, 58, 255), cizgi = Color(92, 74, 50, 255),
	altin = Color(222, 190, 120), yazi = Color(232, 224, 208), soluk = Color(170, 158, 138), yesil = Color(120, 200, 130),
	dugme = Color(120, 92, 48), dugmeUst = Color(150, 116, 60), kapali = Color(60, 54, 48), kirmizi = Color(220, 110, 100),
}

local function Gonder(islem, arg)
	net.Start("SardonEko.Takas")
		net.WriteString(islem)
		net.WriteTable(arg or {})
	net.SendToServer()
end

local function Dugme(ust, metin, etkin, tikla)
	local b = vgui.Create("DButton", ust)
	b:SetText("")
	b.metin, b.etkin = metin, etkin
	b.Paint = function(s, w, h)
		draw.RoundedBox(6, 0, 0, w, h, not s.etkin and R.kapali or (s:IsHovered() and R.dugmeUst or R.dugme))
		draw.SimpleText(s.metin, "SardonEko.Kucuk", w / 2, h / 2, s.etkin and R.yazi or R.soluk, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
	b.DoClick = function(s) if s.etkin then surface.PlaySound("ui/buttonclick.wav") tikla() end end
	return b
end

local function Liste(ust, x, y, w, h)
	local s = vgui.Create("DScrollPanel", ust)
	s:SetPos(x, y)
	s:SetSize(w, h)
	local c = s:GetVBar()
	c:SetWide(8)
	c.Paint = function(_, cw, ch) draw.RoundedBox(4, 0, 0, cw, ch, R.kart) end
	c.btnGrip.Paint = function(_, cw, ch) draw.RoundedBox(4, 0, 0, cw, ch, R.cizgi) end
	c.btnUp.Paint, c.btnDown.Paint = function() end, function() end
	return s
end

local function PencereKur(v)
	local f = E.TakasPencere
	if not IsValid(f) then
		f = vgui.Create("DFrame")
		f:SetSize(math.min(820, ScrW() - 40), math.min(560, ScrH() - 40))
		f:Center()
		f:SetTitle("")
		f:ShowCloseButton(false)
		f:SetDraggable(true)
		f:MakePopup()
		f.OnKeyCodePressed = function(_, k) if k == KEY_ESCAPE then Gonder("iptal") end end
		E.TakasPencere = f
	end
	if IsValid(f.kok) then f.kok:Remove() end
	local w, h = f:GetWide(), f:GetTall()
	local kok = vgui.Create("DPanel", f)
	kok:SetPos(0, 0)
	kok:SetSize(w, h)
	kok.Paint = function() end
	kok.OnMousePressed = function(_, k) f:OnMousePressed(k) end
	kok.OnMouseReleased = function(_, k) f:OnMouseReleased(k) end
	f.kok = kok
	local yarim = (w - 60) / 2

	f.Paint = function(_, pw, ph)
		draw.RoundedBox(10, 0, 0, pw, ph, R.zemin)
		surface.SetDrawColor(R.cizgi)
		surface.DrawOutlinedRect(0, 0, pw, ph, 1)
		draw.SimpleText("Intercambio · " .. v.karsiAd, "SardonEko.Baslik", 24, 14, R.altin)
		draw.SimpleText("Si cambia la oferta se reinician ambos OK · del dinero va %" .. v.vergi .. " a Tesorería", "SardonEko.Kucuk", 26, 54, R.soluk)
		draw.SimpleText("Tu oferta  (bolsillo: " .. v.cep .. " G)", "SardonEko.Kalin", 20, 84, R.yazi)
		draw.SimpleText(v.karsiAd .. " ofrece", "SardonEko.Kalin", 40 + yarim, 84, R.yazi)
		draw.SimpleText(v.benOnay and "Has confirmado" or "Sin confirmar", "SardonEko.Kucuk", 20, ph - 34, v.benOnay and R.yesil or R.soluk)
		draw.SimpleText(v.oOnay and (v.karsiAd .. " confirmó") or (v.karsiAd .. " aún no confirma"), "SardonEko.Kucuk", 220, ph - 34, v.oOnay and R.yesil or R.soluk)
	end

	local sol = Liste(kok, 20, 110, yarim, h - 220)
	for _, es in ipairs(v.envanter) do
		local b = sol:Add("DButton")
		b:Dock(TOP)
		b:DockMargin(0, 0, 8, 4)
		b:SetTall(34)
		b:SetText("")
		b.Paint = function(s, bw, bh)
			draw.RoundedBox(5, 0, 0, bw, bh, es.secili and R.secili or (s:IsHovered() and R.cizgi or R.kart))
			draw.SimpleText((es.secili and "• " or "") .. es.ad, "SardonEko.Kucuk", 10, bh / 2, R.yazi, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
		b.DoClick = function() Gonder("esya", {id = es.id, ekle = not es.secili}) end
	end

	local giris = vgui.Create("DTextEntry", kok)
	giris:SetPos(20, h - 100)
	giris:SetSize(120, 30)
	giris:SetNumeric(true)
	giris:SetFont("SardonEko.Yazi")
	giris:SetValue(tostring(v.para or 0))
	local ayarla = Dugme(kok, "Fijar galeones", true, function() Gonder("para", {miktar = tonumber(giris:GetValue()) or 0}) end)
	ayarla:SetPos(148, h - 100)
	ayarla:SetSize(130, 30)

	local sag = Liste(kok, 40 + yarim, 110, yarim, h - 220)
	if #v.onunEsya == 0 then
		local l = sag:Add("DLabel")
		l:Dock(TOP)
		l:SetTall(34)
		l:SetFont("SardonEko.Kucuk")
		l:SetTextColor(R.soluk)
		l:SetText("No ha puesto objetos.")
	end
	for _, ad in ipairs(v.onunEsya) do
		local p = sag:Add("DPanel")
		p:Dock(TOP)
		p:DockMargin(0, 0, 8, 4)
		p:SetTall(34)
		p.Paint = function(_, pw, ph)
			draw.RoundedBox(5, 0, 0, pw, ph, R.kart)
			draw.SimpleText(ad, "SardonEko.Kucuk", 10, ph / 2, R.yazi, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
	end
	local onunPara = vgui.Create("DLabel", kok)
	onunPara:SetPos(40 + yarim, h - 100)
	onunPara:SetSize(yarim, 30)
	onunPara:SetFont("SardonEko.Kalin")
	onunPara:SetTextColor(R.altin)
	onunPara:SetText("+ " .. (v.onunPara or 0) .. " galeones")

	local onay = Dugme(kok, v.benOnay and "Confirmado" or "Confirmar", not v.benOnay, function() Gonder("onay") end)
	onay:SetPos(w - 252, h - 44)
	onay:SetSize(110, 32)
	local iptal = Dugme(kok, "Cancelar", true, function() Gonder("iptal") end)
	iptal:SetPos(w - 132, h - 44)
	iptal:SetSize(110, 32)
end

net.Receive("SardonEko.TakasDurum", function()
	local tur = net.ReadString()
	local v = net.ReadTable()
	if tur == "istek" then
		Derma_Query(v.kimden .. " quiere intercambiar contigo.", "Petición de intercambio",
			"Aceptar", function() Gonder("kabul", {id = v.id}) end,
			"Rechazar", function() Gonder("red") end)
	elseif tur == "pencere" then
		PencereKur(v)
	elseif tur == "kapat" then
		if IsValid(E.TakasPencere) then E.TakasPencere:Remove() end
		if ix and ix.util and ix.util.Notify then ix.util.Notify(v.sebep or "Intercambio cerrado.") end
	end
end)
