-- Sardon Ekonomi :: ventanas comerciante / tablón / mostrador (cliente)
SardonEkonomi = SardonEkonomi or {}
local E = SardonEkonomi

surface.CreateFont("SardonEko.Baslik", {font = "Playfair Display", size = 32, weight = 600, extended = true})
surface.CreateFont("SardonEko.Yazi", {font = "Montserrat Medium", size = 18, weight = 500, extended = true})
surface.CreateFont("SardonEko.Kalin", {font = "Montserrat SemiBold", size = 18, weight = 600, extended = true})
surface.CreateFont("SardonEko.Kucuk", {font = "Montserrat Medium", size = 16, weight = 500, extended = true})
surface.CreateFont("SardonEko.Etiket", {font = "Playfair Display", size = 40, weight = 600, extended = true})
surface.CreateFont("SardonEko.EtiketKucuk", {font = "Montserrat Medium", size = 24, weight = 500, extended = true})

local R = {
	zemin = Color(24, 19, 15, 248), kart = Color(38, 31, 25, 255), kartAcik = Color(48, 40, 32, 255),
	cizgi = Color(92, 74, 50, 255), altin = Color(222, 190, 120), yazi = Color(232, 224, 208),
	soluk = Color(170, 158, 138), yesil = Color(120, 200, 130), kirmizi = Color(220, 110, 100),
	dugme = Color(120, 92, 48), dugmeUst = Color(150, 116, 60), kapali = Color(60, 54, 48),
	kademe = {Color(150, 200, 120), Color(110, 170, 235), Color(200, 130, 245)},
}

local function Sure(sn)
	sn = math.max(0, math.floor(sn or 0))
	local s, d = math.floor(sn / 3600), math.floor(sn % 3600 / 60)
	if s >= 24 then return math.floor(s / 24) .. " d " .. (s % 24) .. " h" end
	return s .. " h " .. d .. " min"
end

local function Istek(islem, arg)
	net.Start("SardonEko.Istek")
		net.WriteString(islem)
		net.WriteTable(arg or {})
	net.SendToServer()
end

local function Dugme(ust, metin, etkin, tikla)
	local b = vgui.Create("DButton", ust)
	b:SetText("")
	b.metin, b.etkin = metin, etkin
	b.Paint = function(s, w, h)
		local renk = not s.etkin and R.kapali or (s:IsHovered() and R.dugmeUst or R.dugme)
		draw.RoundedBox(6, 0, 0, w, h, renk)
		draw.SimpleText(s.metin, "SardonEko.Kucuk", w / 2, h / 2, s.etkin and R.yazi or R.soluk, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
	b.DoClick = function(s)
		if not s.etkin then return end
		surface.PlaySound("ui/buttonclick.wav")
		tikla()
	end
	return b
end

----------------------------------------------------------------------------------------
local function Cerceve(kip, baslik, alt)
	local f = E.Pencere
	if IsValid(f) and f.kip == kip then
		f.icerik:Clear()
		f.baslik, f.alt = baslik, alt
		return f
	end
	if IsValid(f) then f:Remove() end

	f = vgui.Create("DFrame")
	f.kip, f.baslik, f.alt = kip, baslik, alt
	f:SetSize(math.min(760, ScrW() - 40), math.min(600, ScrH() - 40))
	f:Center()
	f:SetTitle("")
	f:ShowCloseButton(false)
	f:SetDraggable(true)
	f:MakePopup()
	f.Paint = function(s, w, h)
		draw.RoundedBox(10, 0, 0, w, h, R.zemin)
		surface.SetDrawColor(R.cizgi)
		surface.DrawOutlinedRect(0, 0, w, h, 1)
		draw.SimpleText(s.baslik, "SardonEko.Baslik", 24, 16, R.altin)
		draw.SimpleText(s.alt or "", "SardonEko.Kucuk", 26, 56, R.soluk)
		surface.SetDrawColor(R.cizgi)
		surface.DrawRect(24, 112, w - 48, 1)
		if s.bilgi then draw.SimpleText(s.bilgi, "SardonEko.Kucuk", 26, 86, R.yazi) end
		if s.mesaj and s.mesajSon > CurTime() then
			draw.SimpleText(s.mesaj, "SardonEko.Kucuk", w / 2, h - 22, s.mesajRenk or R.yazi, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
	end
	f.OnKeyCodePressed = function(s, k) if k == KEY_ESCAPE or k == KEY_E then s:Remove() end end

	local kapat = Dugme(f, "Cerrar", true, function() f:Remove() end)
	kapat:SetSize(90, 32)
	kapat:SetPos(f:GetWide() - 114, 20)

	f.icerik = vgui.Create("DScrollPanel", f)
	f.icerik:SetPos(20, 122)
	f.icerik:SetSize(f:GetWide() - 40, f:GetTall() - 122 - 44)
	local cubuk = f.icerik:GetVBar()
	cubuk:SetWide(8)
	cubuk.Paint = function(_, w, h) draw.RoundedBox(4, 0, 0, w, h, R.kart) end
	cubuk.btnGrip.Paint = function(_, w, h) draw.RoundedBox(4, 0, 0, w, h, R.cizgi) end
	cubuk.btnUp.Paint, cubuk.btnDown.Paint = function() end, function() end

	E.Pencere = f
	return f
end

----------------------------------------------------------------------------------------
local function TuccarKur(v)
	local f = Cerceve("tuccar", v.ad, v.unvan .. " · los precios cambian con la demanda; se renuevan a las 07:00")
	f.bilgi = string.format("Hoy has ganado: %d / %d G   ·   Impuesto de venta %%%d (Tesorería)   ·   Renueva en %s",
		v.kazanc, v.tavan, v.vergi, Sure(v.sifirlama))

	local function Ara(metin, ust)
		local b = f.icerik:Add("DLabel")
		b:Dock(TOP)
		b:DockMargin(4, ust or 14, 8, 6)
		b:SetTall(26)
		b:SetFont("SardonEko.Kalin")
		b:SetTextColor(R.altin)
		b:SetText(metin)
	end

	local satilik = v.satilik and #v.satilik > 0
	if satilik then
		Ara("En venta", 0)
		for _, s in ipairs(v.satilik) do
			local p = f.icerik:Add("DPanel")
			p:Dock(TOP)
			p:DockMargin(0, 0, 8, 6)
			p:SetTall(58)
			local alt = s.durum == "biliyor" and "Ya conoces este hechizo" or s.durum == "elde" and "Ya lo tienes en el inventario" or (s.aciklama or "")
			p.Paint = function(_, w, h)
				draw.RoundedBox(6, 0, 0, w, h, R.kartAcik)
				draw.SimpleText(s.ad, "SardonEko.Kalin", 16, 9, R.yazi)
				draw.SimpleText(alt, "SardonEko.Kucuk", 16, 32, R.soluk)
				draw.SimpleText(s.fiyat .. " G", "SardonEko.Kalin", w - 140, h / 2, R.altin, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
			end
			local metin = s.durum == "biliyor" and "Ya lo sabes" or s.durum == "elde" and "Lo tienes" or "Comprar"
			local al = Dugme(p, metin, not s.durum and (v.para or 0) >= s.fiyat, function() Istek("al", {mal = s.id, demet = 1}) end)
			al:SetSize(110, 34)
			p.PerformLayout = function(_, w, h) al:SetPos(w - 122, (h - 34) / 2) end
		end
		Ara("Lo que compra")
	end

	if #v.satirlar == 0 then
		local l = f.icerik:Add("DLabel")
		l:Dock(TOP)
		l:SetTall(60)
		l:SetFont("SardonEko.Yazi")
		l:SetTextColor(R.soluk)
		l:SetText("No tienes nada que este comerciante compre.")
		return
	end

	local doldu = v.kazanc >= v.tavan
	for _, s in ipairs(v.satirlar) do
		local p = f.icerik:Add("DPanel")
		p:Dock(TOP)
		p:DockMargin(0, 0, 8, 6)
		p:SetTall(58)
		p.Paint = function(_, w, h)
			draw.RoundedBox(6, 0, 0, w, h, s.elde > 0 and R.kartAcik or R.kart)
			draw.RoundedBox(4, 12, h / 2 - 4, 8, 8, R.kademe[s.kademe] or R.soluk)
			draw.SimpleText(s.ad, "SardonEko.Kalin", 30, 9, s.elde > 0 and R.yazi or R.soluk)
			draw.SimpleText("Tienes: " .. s.elde .. "   ·   " .. s.n .. " uds = " .. s.p .. " G", "SardonEko.Kucuk", 30, 32, R.soluk)
			local bx, bw = w - 330, 90
			draw.RoundedBox(3, bx, h / 2 - 3, bw, 6, R.kart)
			draw.RoundedBox(3, bx, h / 2 - 3, bw * s.oran / 100, 6, s.oran >= 80 and R.yesil or s.oran >= 55 and R.altin or R.kirmizi)
			draw.SimpleText("demanda %" .. s.oran, "SardonEko.Kucuk", bx + bw / 2, h / 2 + 6, R.soluk, TEXT_ALIGN_CENTER)
		end

		local yeter = s.elde >= s.n and not doldu
		local bir = Dugme(p, "1 lote", yeter, function() Istek("sat", {mal = s.id, demet = 1}) end)
		bir:SetSize(96, 34)
		local hepsi = Dugme(p, "Vender todo", yeter, function() Istek("sat", {mal = s.id, demet = 0}) end)
		hepsi:SetSize(110, 34)
		p.PerformLayout = function(_, w, h)
			hepsi:SetPos(w - 122, (h - 34) / 2)
			bir:SetPos(w - 226, (h - 34) / 2)
		end
	end

	if v.stok then
		local b = f.icerik:Add("DLabel")
		b:Dock(TOP)
		b:DockMargin(4, 14, 8, 6)
		b:SetTall(26)
		b:SetFont("SardonEko.Kalin")
		b:SetTextColor(R.altin)
		b:SetText(#v.stok > 0 and "En venta · piezas traídas por cazadores" or "En venta · sin stock (llega cuando los cazadores venden)")
		for _, s in ipairs(v.stok) do
			local p = f.icerik:Add("DPanel")
			p:Dock(TOP)
			p:DockMargin(0, 0, 8, 6)
			p:SetTall(58)
			p.Paint = function(_, w, h)
				draw.RoundedBox(6, 0, 0, w, h, R.kart)
				draw.RoundedBox(4, 12, h / 2 - 4, 8, 8, R.kademe[s.kademe] or R.soluk)
				draw.SimpleText(s.ad, "SardonEko.Kalin", 30, 9, R.yazi)
				draw.SimpleText("Stock: " .. s.stok .. "   ·   " .. s.n .. " uds = " .. s.fiyat .. " G", "SardonEko.Kucuk", 30, 32, R.soluk)
			end
			local al = Dugme(p, "Comprar 1 lote", s.stok >= s.n and (v.para or 0) >= s.fiyat, function() Istek("al", {mal = s.id, demet = 1}) end)
			al:SetSize(110, 34)
			p.PerformLayout = function(_, w, h) al:SetPos(w - 122, (h - 34) / 2) end
		end
	end
end

----------------------------------------------------------------------------------------
local function PanoKur(v)
	local f = Cerceve("pano", "Tablón de encargos", "Entregas el material aquí; la recompensa se paga al momento (si superas el techo diario, va al banco mañana)")
	f.bilgi = string.format("Hoy has ganado: %d / %d G   ·   Encargos diarios en %s   ·   Semanal en %s",
		v.kazanc, v.tavan, Sure(v.sifirlama), Sure(v.haftaSonu))

	for i, is in ipairs(v.isler) do
		local p = f.icerik:Add("DPanel")
		p:Dock(TOP)
		p:DockMargin(0, 0, 8, 8)
		p:SetTall(48 + #is.kalemler * 24 + 12)
		local hazir = is.durum == 0
		for _, k in ipairs(is.kalemler) do if k.elde < k.adet then hazir = false end end

		p.Paint = function(_, w, h)
			draw.RoundedBox(8, 0, 0, w, h, is.haftalik and R.kartAcik or R.kart)
			draw.SimpleText(is.haftalik and "Encargo semanal" or ("Encargo diario " .. i), "SardonEko.Kalin", 16, 12, is.haftalik and R.altin or R.yazi)
			draw.SimpleText("Recompensa: " .. is.odul .. " G", "SardonEko.Kalin", w - 250, 12, R.altin, TEXT_ALIGN_RIGHT)
			for j, k in ipairs(is.kalemler) do
				local tamam = k.elde >= k.adet
				draw.SimpleText(k.adet .. " × " .. k.ad, "SardonEko.Yazi", 28, 20 + j * 24, R.yazi)
				draw.SimpleText(math.min(k.elde, k.adet) .. "/" .. k.adet, "SardonEko.Yazi", w - 250, 20 + j * 24,
					is.durum == 1 and R.soluk or (tamam and R.yesil or R.kirmizi), TEXT_ALIGN_RIGHT)
			end
			if is.durum == 1 then
				draw.SimpleText("Entregado", "SardonEko.Kalin", w - 24, h / 2, R.yesil, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
			end
		end

		if is.durum == 0 then
			local teslim = Dugme(p, "Entregar", hazir, function() Istek("teslim", {slot = is.slot}) end)
			teslim:SetSize(110, 34)
			local degistir
			if not is.haftalik then
				degistir = Dugme(p, is.degisti == 1 and "Cambiado" or "Otro encargo", is.degisti == 0, function() Istek("degistir", {slot = is.slot}) end)
				degistir:SetSize(110, 34)
			end
			p.PerformLayout = function(_, w, h)
				teslim:SetPos(w - 126, (h - 34) / 2)
				if degistir then degistir:SetPos(w - 244, (h - 34) / 2) end
			end
		end
	end
end

----------------------------------------------------------------------------------------
local function Satir(ust, h)
	local p = ust:Add("DPanel")
	p:Dock(TOP)
	p:DockMargin(0, 0, 8, 6)
	p:SetTall(h or 50)
	return p
end

local function TezgahKur(v)
	local f = Cerceve("tezgah", "Mostrador de anuncios", "Compraventa entre jugadores · el dinero va al banco del vendedor · anuncios 3 días")
	f.bilgi = string.format("En el bolsillo: %d G   ·   Tus anuncios: %d / %d   ·   Impuesto %%%d (Tesorería, del vendedor)",
		v.para, #v.benim, v.sinir, v.vergi)
	f.sekme = f.sekme or "pazar"

	local ust = f.icerik:Add("DPanel")
	ust:Dock(TOP)
	ust:DockMargin(0, 0, 8, 8)
	ust:SetTall(36)
	ust.Paint = function() end
	for i, s in ipairs({{"pazar", "Mercado (" .. #v.pazar .. ")"}, {"benim", "Mis anuncios (" .. #v.benim .. ")"}, {"ver", "Publicar"}}) do
		local b = Dugme(ust, s[2], true, function() f.sekme = s[1] TezgahKur(v) end)
		b:SetSize(170, 32)
		b:SetPos((i - 1) * 178, 0)
		if f.sekme == s[1] then b.metin = "• " .. s[2] end
	end

	local function Bos(metin)
		local l = f.icerik:Add("DLabel")
		l:Dock(TOP)
		l:SetTall(50)
		l:SetFont("SardonEko.Yazi")
		l:SetTextColor(R.soluk)
		l:SetText(metin)
	end

	if f.sekme == "pazar" then
		if #v.pazar == 0 then return Bos("No hay anuncios en el mostrador.") end
		for _, il in ipairs(v.pazar) do
			local p = Satir(f.icerik, 50)
			p.Paint = function(_, w, h)
				draw.RoundedBox(6, 0, 0, w, h, R.kart)
				draw.SimpleText(il.ad or "?", "SardonEko.Kalin", 16, 7, R.yazi)
				draw.SimpleText("Vendedor: " .. (il.satici or "?"), "SardonEko.Kucuk", 16, 28, R.soluk)
				draw.SimpleText(il.fiyat .. " G", "SardonEko.Kalin", w - 140, h / 2, R.altin, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
			end
			local b = Dugme(p, "Comprar", v.para >= il.fiyat, function() Istek("al", {ilan = il.id}) end)
			b:SetSize(110, 32)
			p.PerformLayout = function(_, w, h) b:SetPos(w - 122, (h - 32) / 2) end
		end
	elseif f.sekme == "benim" then
		if #v.benim == 0 then return Bos("No tienes anuncios. En «Publicar» pon un objeto del inventario.") end
		for _, il in ipairs(v.benim) do
			local p = Satir(f.icerik, 50)
			p.Paint = function(_, w, h)
				draw.RoundedBox(6, 0, 0, w, h, R.kart)
				draw.SimpleText(il.ad or "?", "SardonEko.Kalin", 16, 7, R.yazi)
				local durum = il.durum == 2 and "Caducado — recupera" or ("En venta · quedan " .. Sure(il.kalan))
				draw.SimpleText(durum, "SardonEko.Kucuk", 16, 28, il.durum == 2 and R.kirmizi or R.soluk)
				draw.SimpleText(il.fiyat .. " G", "SardonEko.Kalin", w - 140, h / 2, R.altin, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
			end
			local b = Dugme(p, "Recuperar", true, function() Istek("geri", {ilan = il.id}) end)
			b:SetSize(110, 32)
			p.PerformLayout = function(_, w, h) b:SetPos(w - 122, (h - 32) / 2) end
		end
	else
		if #v.envanter == 0 then return Bos("No hay objetos publicables en el inventario.") end
		local dolu = #v.benim >= v.sinir
		for _, es in ipairs(v.envanter) do
			local p = Satir(f.icerik, 50)
			p.Paint = function(_, w, h)
				draw.RoundedBox(6, 0, 0, w, h, R.kart)
				draw.SimpleText(es.ad or "?", "SardonEko.Kalin", 16, h / 2, R.yazi, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			end
			local giris = vgui.Create("DTextEntry", p)
			giris:SetSize(80, 30)
			giris:SetNumeric(true)
			giris:SetPlaceholderText("precio")
			giris:SetFont("SardonEko.Yazi")
			local b = Dugme(p, "Publicar", not dolu, function()
				local fiyat = tonumber(giris:GetValue())
				if not fiyat or fiyat < 1 then
					f.mesaj, f.mesajSon, f.mesajRenk = "Escribe un precio primero.", CurTime() + 4, R.kirmizi
					return
				end
				Istek("ilan", {item = es.id, fiyat = math.floor(fiyat)})
			end)
			b:SetSize(110, 32)
			p.PerformLayout = function(_, w, h)
				b:SetPos(w - 122, (h - 32) / 2)
				giris:SetPos(w - 212, (h - 30) / 2)
			end
		end
	end
end

----------------------------------------------------------------------------------------
net.Receive("SardonEko.Pencere", function()
	local kip = net.ReadString()
	local v = net.ReadTable()
	if kip == "tuccar" then TuccarKur(v) elseif kip == "pano" then PanoKur(v) elseif kip == "tezgah" then TezgahKur(v) end
end)

net.Receive("SardonEko.Bildir", function()
	local metin, tur = net.ReadString(), net.ReadString()
	local f = E.Pencere
	if IsValid(f) then
		f.mesaj, f.mesajSon = metin, CurTime() + 6
		f.mesajRenk = tur == "basari" and R.yesil or tur == "uyari" and R.kirmizi or R.yazi
	end
	if ix and ix.util and ix.util.Notify then ix.util.Notify(metin) end
end)
