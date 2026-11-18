-- "addons\\sardonmatbaa\\lua\\sardon_matbaa\\cl_menu.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Baskı makinesi paneli (matbaa-ui tasarımı: koyu yeşil-siyah, altın çerçeve, Montserrat).
-- Hammadde koy/geri al, format seçimi, görsel bağlantısı + önizleme, adet seçimi ve baskıyı
-- başlatma. Sunucu her şeyi yeniden doğrular (sv_init.lua); net mesajları değişmedi.
-- Eski panel: tools/cl_menu_eski.lua.txt
-- NOT: istemcide cl_ dosyaları sh_ dosyalarından önce yükleniyor -- Config/format tablosu
-- sadece fonksiyonların içinde okunuyor.
SardonMatbaa = SardonMatbaa or {}
SardonMatbaa.ClientStock = SardonMatbaa.ClientStock or { ink = 0, paper = 0 }

-- ============= TEMA (matbaa-ui/assets/palette.json) =============
local T = {
	background = Color(12, 16, 14, 250),
	panel = Color(16, 23, 19, 235),
	raised = Color(21, 28, 23, 240),
	inset = Color(11, 17, 13, 255),
	hover = Color(34, 40, 27, 255),
	gold = Color(198, 161, 91),
	goldBright = Color(240, 214, 154),
	goldDim = Color(117, 99, 64),
	border = Color(110, 92, 55),
	borderSoft = Color(110, 92, 55, 110),
	borderFaint = Color(110, 92, 55, 55),
	text = Color(238, 231, 214),
	muted = Color(170, 168, 149),
	faint = Color(130, 132, 112),
	success = Color(159, 185, 154),
	danger = Color(216, 134, 119),
	disabled = Color(76, 80, 68),
	paper = Color(232, 223, 197),
	ink = Color(16, 23, 19),
	shade = Color(0, 0, 0, 110),
	grid = Color(165, 148, 96, 14),
}

-- Paint içinde her karede Color() oluşturmamak necesita sabit renkler
local C_106_91_58_140 = Color(106, 91, 58, 140)
local C_107_98_62 = Color(107, 98, 62)
local C_114_118_94 = Color(114, 118, 94)
local C_120_104_70 = Color(120, 104, 70)
local C_120_122_104 = Color(120, 122, 104)
local C_125_107_67_150 = Color(125, 107, 67, 150)
local C_127_132_111 = Color(127, 132, 111)
local C_128_107_62 = Color(128, 107, 62)
local C_140_122_84_150 = Color(140, 122, 84, 150)
local C_140_137_111 = Color(140, 137, 111)
local C_144_123_71 = Color(144, 123, 71)
local C_145_153_131 = Color(145, 153, 131)
local C_146_149_129 = Color(146, 149, 129)
local C_148_140_105 = Color(148, 140, 105)
local C_150_72_60 = Color(150, 72, 60)
local C_152_131_84 = Color(152, 131, 84)
local C_155_155_133 = Color(155, 155, 133)
local C_156_149_126 = Color(156, 149, 126)
local C_162_165_142 = Color(162, 165, 142)
local C_165_165_141 = Color(165, 165, 141)
local C_167_146_96 = Color(167, 146, 96)
local C_167_167_148 = Color(167, 167, 148)
local C_170_165_138 = Color(170, 165, 138)
local C_172_142_80 = Color(172, 142, 80)
local C_180_182_152 = Color(180, 182, 152)
local C_183_180_162 = Color(183, 180, 162)
local C_186_195_175 = Color(186, 195, 175)
local C_198_161_91_6 = Color(198, 161, 91, 6)
local C_205_183_131 = Color(205, 183, 131)
local C_210_173_96 = Color(210, 173, 96)
local C_214_178_106 = Color(214, 178, 106)
local C_215_179_107 = Color(215, 179, 107)
local C_222_205_160 = Color(222, 205, 160)
local C_223_214_184 = Color(223, 214, 184)
local C_232_213_172 = Color(232, 213, 172)
local C_23_30_22_170 = Color(23, 30, 22, 170)
local C_34_40_27_230 = Color(34, 40, 27, 230)
local C_50_46_28_140 = Color(50, 46, 28, 140)

local S = 1

local function sc(v) return math.floor(v * S + 0.5) end

-- Windows/macOS gerçek font yüzü adlarını, Linux dosya adını kullanır
-- (Montserrat dosyaları Workshop koleksiyonuyla resource/fonts altına iniyor).
-- 2026-10-01 Windows istemcide ölçüldü: "Montserrat Medium"/"Montserrat SemiBold" ve
-- "Montserrat"+700 Workshop'taki yüzlere çözülüyor; "Montserrat"+400 ise başka, eski ve daha
-- geniş bir Montserrat kopyasına düşüyor -- bu yüzden Regular rolleri de Medium kullanır.
local FACES = {
	[400] = { "Montserrat Medium", "montserrat-medium.ttf" },
	[500] = { "Montserrat Medium", "montserrat-medium.ttf" },
	[600] = { "Montserrat SemiBold", "montserrat-semibold.ttf" },
	[700] = { "Montserrat", "montserrat-bold.ttf" },
}

local FONTS = {
	Eyebrow = { 11, 600, 9 },
	Title = { 34, 500, 22 },
	Sub = { 13, 400, 11 },
	Section = { 14, 600, 11 },
	Number = { 11, 500, 9 },
	Caption = { 10, 500, 9 },
	Body = { 15, 500, 12 },
	Label = { 13, 500, 11 },
	Value = { 13, 600, 11 },
	Small = { 12, 400, 10 },
	Tiny = { 10, 400, 9 },
	Btn = { 12, 600, 10 },
	Big = { 22, 500, 15 },
	Qty = { 18, 600, 13 },
	Print = { 17, 700, 13 },
}

local function createFonts()
	local linux = system.IsLinux()

	for name, d in pairs(FONTS) do
		local face = FACES[d[2]]

		surface.CreateFont("SardonMatbaa." .. name, {
			font = linux and face[2] or face[1],
			size = math.max(d[3], sc(d[1])),
			weight = d[2],
			antialias = true,
			extended = true,
		})
	end

	-- Font yüklenmediyse sessizce yedek fonta düşmesin: var olmayan bir fontla aynı genişlikte
	-- çiziliyorsa konsola uyarı yaz (bir kez).
	if !SardonMatbaa.FontChecked then
		SardonMatbaa.FontChecked = true

		surface.CreateFont("SardonMatbaa.FontProbe", { font = "SardonMatbaaYokFont", size = math.max(12, sc(15)), weight = 500, extended = true })
		surface.SetFont("SardonMatbaa.FontProbe")
		local fw = surface.GetTextSize("MMMMMMMMMM0123456789")
		surface.SetFont("SardonMatbaa.Body")
		local mw = surface.GetTextSize("MMMMMMMMMM0123456789")

		if fw == mw then
			MsgC(Color(216, 134, 119), "[Imprenta] No se pudo cargar Montserrat; la interfaz usa una fuente de reserva. Revisa el paquete de fuentes del Workshop (resource/fonts/montserrat-*.ttf).\n")
		end
	end
end

-- ============= ÇİZİM YARDIMCILARI =============
-- cl_1doku.lua yüklenmemişse (ör. restart öncesi canlı yenileme) yedek çizime düşer
local function uiDoku(ad, x, y, w, h, renk)
	return SardonMatbaa.UIDokuCiz != nil and SardonMatbaa.UIDokuCiz(ad, x, y, w, h, renk) or false
end

local matGradR = Material("vgui/gradient-r")
local matGradD = Material("vgui/gradient-d")

local function icon(name, x, y, size, col)
	if !uiDoku("icon-" .. name, x, y, size, size, col or T.gold) then
		surface.SetDrawColor(col or T.gold)
		surface.DrawOutlinedRect(x + size * 0.2, y + size * 0.2, size * 0.6, size * 0.6, 1)
	end
end

local function diamond(x, y, r, col)
	surface.SetDrawColor(col or T.gold)
	surface.DrawLine(x, y - r, x + r, y)
	surface.DrawLine(x + r, y, x, y + r)
	surface.DrawLine(x, y + r, x - r, y)
	surface.DrawLine(x - r, y, x, y - r)
end

local function textWidth(text, font, spacing)
	surface.SetFont(font)
	local w = surface.GetTextSize(text)
	spacing = spacing and spacing > 0 and math.max(1, math.Round(spacing)) or 0

	return w + math.max(0, utf8.len(text) - 1) * (spacing or 0)
end

-- Harf aralıklı metin (CSS letter-spacing karşılığı)
local function spaced(text, font, x, y, col, spacing, alignX, alignY)
	-- kesirli aralık yuvarlanınca harfler arasında düzensiz boşluk oluşuyor; tam sayıya çek
	spacing = spacing and spacing > 0 and math.max(1, math.Round(spacing)) or 0

	if spacing <= 0 then
		return draw.SimpleText(text, font, x, y, col, alignX, alignY)
	end

	surface.SetFont(font)
	local total = textWidth(text, font, spacing)
	local _, th = surface.GetTextSize("Ag")

	if alignX == TEXT_ALIGN_CENTER then x = x - total / 2 elseif alignX == TEXT_ALIGN_RIGHT then x = x - total end
	if alignY == TEXT_ALIGN_CENTER then y = y - th / 2 elseif alignY == TEXT_ALIGN_BOTTOM then y = y - th end

	surface.SetTextColor(col)

	-- her harfin yeri önekin genişliğinden hesaplanır (tek tek harf genişliği toplamı
	-- kerning/yuvarlama yüzünden düzensiz boşluk bırakıyordu)
	local i = 0

	for pos, code in utf8.codes(text) do
		local pre = pos > 1 and surface.GetTextSize(text:sub(1, pos - 1)) or 0
		surface.SetTextPos(math.floor(x + pre + i * spacing), math.floor(y))
		surface.DrawText(utf8.char(code))
		i = i + 1
	end

	return total, th
end

-- Çift çizgili altın çerçeve (+ isteğe bağlı süslü köşe PNG'leri)
local function frame(x, y, w, h, ornate)
	surface.SetDrawColor(T.border)
	surface.DrawOutlinedRect(x, y, w, h, 1)
	surface.SetDrawColor(T.borderFaint)
	surface.DrawOutlinedRect(x + 4, y + 4, w - 8, h - 8, 1)

	if !ornate then return end

	local c = sc(ornate)

	for _, k in ipairs({ { "tl", x - 2, y - 2 }, { "tr", x + w - c + 2, y - 2 }, { "bl", x - 2, y + h - c + 2 }, { "br", x + w - c + 2, y + h - c + 2 } }) do
		if !uiDoku("corner-" .. k[1], k[2], k[3], c, c) then
			surface.SetDrawColor(T.gold)
			surface.DrawOutlinedRect(k[2] + 2, k[3] + 2, c * 0.4, c * 0.4, 1)
		end
	end
end

local function fmtTime(sec)
	sec = math.max(0, math.ceil(sec))

	return string.format("%02d:%02d", math.floor(sec / 60), sec % 60)
end

local function invCount(uniqueID)
	local char = LocalPlayer():GetCharacter()
	local inv = char and char:GetInventory()

	return inv and inv:GetItemCount(uniqueID) or 0
end

local FORMAT_ICONS = { gazete = "newspaper", poster = "poster", buyuk_poster = "large-poster", afis = "billboard" }
local FALLBACK_ICONS = { "newspaper", "poster", "large-poster", "billboard" }

local function formatIcon(f)
	return FORMAT_ICONS[f.id] or FALLBACK_ICONS[f.index] or "poster"
end

-- ============= KONTROLLER =============
-- Çerçeveli ikincil buton. opts: font, icon, enabled(fn), caption(fn)
local function makeButton(parent, text, onClick, opts)
	opts = opts or {}

	local btn = vgui.Create("DButton", parent)
	btn:SetText("")
	btn.caption = text
	btn.opts = opts

	btn.DoClick = function(self)
		if opts.enabled and !opts.enabled() then return end
		surface.PlaySound("ui/buttonclick.wav")
		onClick(self)
	end

	function btn:Paint(w, h)
		local enabled = !opts.enabled or opts.enabled()
		local hov = enabled and self:IsHovered()
		local down = hov and self:IsDown()

		surface.SetDrawColor(down and T.inset or (hov and T.hover or C_198_161_91_6))
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(enabled and (hov and T.gold or T.border) or T.borderFaint)
		surface.DrawOutlinedRect(0, 0, w, h, 1)

		local label = isfunction(self.caption) and self.caption() or self.caption
		local col = enabled and (hov and T.goldBright or C_222_205_160) or T.disabled
		local font = opts.font or "SardonMatbaa.Btn"

		if opts.icon then
			local is = math.floor(h * 0.45)
			local tw = label != "" and textWidth(label, font) + sc(8) or 0
			local x0 = (w - is - tw) / 2

			icon(opts.icon, x0, (h - is) / 2, is, enabled and (hov and T.goldBright or T.gold) or T.goldDim)

			if label != "" then
				draw.SimpleText(label, font, x0 + is + sc(8), h / 2, col, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			end
		else
			draw.SimpleText(label, font, w / 2, h / 2, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
	end

	return btn
end

-- "01  MATERIALES ────────── MOCHILA · IMPRENTA" título
local function sectionTitle(parent, num, text, caption)
	local p = vgui.Create("DPanel", parent)
	p:Dock(TOP)
	p:SetTall(sc(22))
	p:DockMargin(0, 0, 0, sc(8))

	function p:Paint(w, h)
		local nw = spaced(num, "SardonMatbaa.Number", 0, h / 2, T.goldDim, 1, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		local tw = spaced(text, "SardonMatbaa.Section", nw + sc(10), h / 2, T.goldBright, 1.4, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		local right = w
		local cap = isfunction(caption) and caption() or caption

		if cap and cap != "" then
			right = w - spaced(cap, "SardonMatbaa.Caption", w, h / 2, T.faint, 1, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER) - sc(12)
		end

		local lx = nw + tw + sc(22)

		if right > lx then
			surface.SetDrawColor(138, 115, 66, 90)
			surface.SetMaterial(matGradR)
			surface.DrawTexturedRectUV(lx, h / 2, right - lx, 1, 1, 0, 0, 1)
		end
	end

	return p
end

-- ============= PANEL =============
function SardonMatbaa.OpenMenu(machine, ink, paper)
	if IsValid(SardonMatbaa.Menu) then SardonMatbaa.Menu:Remove() end

	local cfg = SardonMatbaa.Config
	local formats = cfg.Formatlar

	SardonMatbaa.ClientStock.ink = ink
	SardonMatbaa.ClientStock.paper = paper

	-- Hedef 1320×880 (1080p'de 1:1); küçük ekranlarda ölçek düşer, sağ kolon kayar,
	-- adet/maliyet ve baskı düğmesi sabit kalır
	S = math.Clamp(math.min(ScrW() * 0.96 / 1320, ScrH() * 0.95 / 880), 0.62, math.max(1, ScrH() / 1080))
	createFonts()

	local state = {
		format = SardonMatbaa.LastFormat and SardonMatbaa.GetFormat(SardonMatbaa.LastFormat) or formats[1],
		url = nil,       -- doğrulanmış (beyaz listeden geçmiş) bağlantı
		urlError = nil,
		copies = 1,
		sentAt = 0,      -- baskı isteği gönderildi; sunucu yanıtına kadar tekrar gönderim kapalı
		lastTransfer = 0,
	}

	local function stock() return SardonMatbaa.ClientStock end
	local function maxCopies(format)
		return SardonMatbaa.GetMaxCopies(format or state.format, stock().ink, stock().paper)
	end
	local function busy() return IsValid(machine) and machine:IsBusy() end
	local function myJob()
		local char = LocalPlayer():GetCharacter()

		return busy() and char and machine:GetJobOwner() == char:GetName()
	end
	local function imageState()
		if !state.url then return nil end
		local _, st = SardonMatbaa.GetMaterial(state.url)

		return st
	end
	local function canPrint()
		return state.url != nil and imageState() == "ok" and maxCopies() > 0 and IsValid(machine)
			and !busy() and CurTime() > state.sentAt + 3
	end

	-- --- kök: tüm ekranı bulanıklaştıran katman (oyun dünyası arkada görünür) ---
	local root = vgui.Create("EditablePanel")
	root:SetSize(ScrW(), ScrH())
	root:MakePopup()
	root:SetKeyboardInputEnabled(true)
	root.startTime = SysTime()
	SardonMatbaa.Menu = root

	function root:Paint(w, h)
		Derma_DrawBackgroundBlur(self, self.startTime)
		surface.SetDrawColor(5, 8, 6, 120)
		surface.DrawRect(0, 0, w, h)
	end

	local W = math.min(sc(1320), ScrW() - 24)
	local H = math.min(sc(880), ScrH() - 24)
	local padX, padTop = sc(32), sc(26)

	local win = vgui.Create("EditablePanel", root)
	win:SetSize(W, H)
	win:Center()
	win:SetAlpha(0)
	win:AlphaTo(255, 0.18)

	function root:Think()
		-- ESC: oyun menüsü yerine paneli kapat (önce büyük önizleme)
		if gui.IsGameUIVisible() then
			gui.HideGameUI()

			if IsValid(self.zoom) then self.zoom:Remove() else self:Remove() end
			return
		end

		if !IsValid(machine) or LocalPlayer():GetPos():DistToSqr(machine:GetPos()) > 220 * 220 or !LocalPlayer():Alive() then
			self:Remove()
			return
		end

		-- Stok azalırsa (geri alma, başka bir baskı) seçili adet yeni sınıra çekilir
		state.copies = math.Clamp(state.copies, 1, math.max(1, maxCopies()))
	end

	function root:OnKeyCodePressed(key)
		if key == KEY_ESCAPE then self:Remove() end
	end

	function win:Paint(w, h)
		-- zemin
		surface.SetDrawColor(T.background)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(20, 26, 21, 140)
		surface.SetMaterial(matGradD)
		surface.DrawTexturedRect(0, 0, w, h * 0.5)

		-- dış çerçeve: altın çizgi + iç ince çizgi + süslü köşeler
		surface.SetDrawColor(168, 136, 73)
		surface.DrawOutlinedRect(0, 0, w, h, 1)
		surface.SetDrawColor(T.borderSoft)
		surface.DrawOutlinedRect(sc(7), sc(7), w - sc(14), h - sc(14), 1)

		local c = sc(56)

		uiDoku("corner-tl", 0, 0, c, c)
		uiDoku("corner-tr", w - c, 0, c, c)
		uiDoku("corner-bl", 0, h - c, c, c)
		uiDoku("corner-br", w - c, h - c, c, c)

		-- başlık: rozet + yazılar
		local bs = sc(66)
		local bx, by = padX, padTop

		surface.SetDrawColor(55, 53, 29, 70)
		surface.DrawRect(bx, by, bs, bs)
		surface.SetDrawColor(161, 129, 67)
		surface.DrawOutlinedRect(bx, by, bs, bs, 1)
		surface.SetDrawColor(T.borderFaint)
		surface.DrawOutlinedRect(bx - sc(5), by - sc(5), bs + sc(10), bs + sc(10), 1)

		if !uiDoku("press-seal", bx + sc(4), by + sc(4), bs - sc(8), bs - sc(8)) then
			icon("print", bx + bs * 0.25, by + bs * 0.25, bs * 0.5, T.goldBright)
		end

		diamond(bx + bs / 2, by + bs, sc(4), T.gold)

		local tx = bx + bs + sc(20)

		spaced("ARTE Y PRODUCCIÓN", "SardonMatbaa.Eyebrow", tx, by + sc(4), T.gold, 2.2, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		spaced("IMPRENTA", "SardonMatbaa.Title", tx - 1, by + sc(18), T.goldBright, sc(6), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		draw.SimpleText("Convierte ideas en papel y deja tu huella en el mundo.", "SardonMatbaa.Sub", tx, by + sc(58), C_183_180_162, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

		-- makine durumu
		local sx, sy = w - padX - sc(34) - sc(26), by + bs / 2
		local stText, stCol

		if busy() then
			stText = (myJob() and "Impresión en curso · " or "Máquina ocupada · ") .. fmtTime(machine:GetJobEnd() - CurTime())
			stCol = T.gold
		else
			stText, stCol = "Imprenta lista", T.success
		end

		local stw = draw.SimpleText(stText, "SardonMatbaa.Label", sx, sy, C_186_195_175, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		draw.RoundedBox(sc(3), sx - stw - sc(15), sy - sc(3), sc(6), sc(6), stCol)

		-- başlık altı ayraç
		local ry = by + bs + sc(18)
		local sepW = sc(240)

		surface.SetDrawColor(103, 86, 47)
		surface.DrawLine(padX, ry, w / 2 - sepW / 2, ry)
		surface.DrawLine(w / 2 + sepW / 2, ry, w - padX, ry)

		local sepH = sepW * 24 / 512

		if !uiDoku("separator-gold", w / 2 - sepW / 2, ry - sepH / 2, sepW, sepH) then
			diamond(w / 2, ry, sc(4), T.gold)
		end

		-- alt bilgi
		local fy = h - sc(26)

		surface.SetDrawColor(T.borderFaint)
		surface.DrawLine(padX, fy - sc(20), w - padX, fy - sc(20))

		local kw = textWidth("ESC", "SardonMatbaa.Caption") + sc(16)
		surface.SetDrawColor(T.border)
		surface.DrawOutlinedRect(padX, fy - sc(11), kw, sc(22), 1)
		draw.SimpleText("ESC", "SardonMatbaa.Caption", padX + kw / 2, fy, T.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		draw.SimpleText("Cerrar", "SardonMatbaa.Small", padX + kw + sc(10), fy, T.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		spaced("TODA BUENA HISTORIA EMPIEZA CON UNA PÁGINA.", "SardonMatbaa.Caption", w / 2, fy, T.goldDim, 1.6, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		spaced(string.format("DURACIÓN: %d S + %d S POR COPIA", cfg.SabitSure, cfg.AdetBasinaSure), "SardonMatbaa.Caption", w - padX, fy, T.faint, 1, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	end

	local close = makeButton(win, "", function() root:Remove() end, { icon = "close" })
	close:SetSize(sc(34), sc(34))
	close:SetPos(W - padX - sc(34), padTop + sc(66) / 2 - sc(17))

	-- ============= ÇALIŞMA ALANI =============
	local top = padTop + sc(66) + sc(40)
	local bottom = H - sc(58)
	local gap = sc(30)
	local leftW = math.Clamp(math.floor((W - padX * 2) * 0.29), sc(300), sc(380))
	local rx = padX + leftW + gap
	local RW = W - rx - padX

	-- ------------- SOL: ÖNİZLEME -------------
	local preview = vgui.Create("DPanel", win)
	preview:SetPos(padX, top)
	preview:SetSize(leftW, bottom - top)

	-- Kağıt dikdörtgeni (format oranında, verilen alana ortalanmış)
	local function paperRect(f, x, y, w, h)
		local s = math.min(w / f.genislik, h / f.yukseklik)
		local pw, ph = math.floor(f.genislik * s), math.floor(f.yukseklik * s)

		return x + math.floor((w - pw) / 2), y + math.floor((h - ph) / 2), pw, ph
	end

	-- Kağıdı + görseli çizer; görsel kırpılmaz/esnetilmez, boşluk papel rengi kalır
	local function drawPaper(f, px, py, pw, ph, big)
		surface.SetDrawColor(T.shade)
		surface.DrawRect(px + sc(8), py + sc(11), pw, ph)
		surface.SetDrawColor(123, 107, 68, 120)
		surface.DrawRect(px + sc(3), py + sc(3), pw, ph)
		surface.SetDrawColor(T.paper)
		surface.DrawRect(px, py, pw, ph)

		local msg, msgCol

		if state.url then
			local mat, st = SardonMatbaa.GetMaterial(state.url)

			if mat then
				SardonMatbaa.DrawFit(mat, px, py, pw, ph)
			elseif st == "fail" then
				msg, msgCol = "No se pudo cargar la imagen", C_150_72_60
			else
				msg, msgCol = "Cargando" .. string.rep(".", math.floor(CurTime() * 3) % 4), C_120_104_70
			end
		else
			local is = math.min(pw, ph) * 0.28
			icon(formatIcon(f), px + pw / 2 - is / 2, py + ph / 2 - is * 0.85, is, C_140_122_84_150)
			msg, msgCol = "Esperando enlace de imagen", C_120_104_70
		end

		if msg then
			draw.SimpleText(msg, big and "SardonMatbaa.Body" or "SardonMatbaa.Small", px + pw / 2, py + ph / 2 + (state.url and 0 or sc(14)), msgCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end

		-- hafif iç gölge
		surface.SetDrawColor(100, 81, 46, 40)
		surface.DrawOutlinedRect(px, py, pw, ph, 1)
	end

	local stageTop, stageH = sc(68), 0

	function preview:Paint(w, h)
		surface.SetDrawColor(T.panel)
		surface.DrawRect(0, 0, w, h)
		frame(0, 0, w, h)

		local ix = sc(20)

		spaced("VISTA PREVIA", "SardonMatbaa.Section", ix, sc(28), T.goldBright, 1.2, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		surface.SetDrawColor(T.borderFaint)
		surface.DrawLine(ix, sc(56), w - ix, sc(56))

		-- sahne: ızgara + köşe işaretleri + ölçüler
		stageH = math.max(sc(160), h - sc(68) - sc(230))
		local sx, sy, sw, sh = ix, stageTop, w - ix * 2, stageH

		surface.SetDrawColor(T.grid)
		for gx = sx, sx + sw, sc(24) do surface.DrawLine(gx, sy, gx, sy + sh) end
		for gy = sy, sy + sh, sc(24) do surface.DrawLine(sx, gy, sx + sw, gy) end

		for _, p in ipairs({ { sx + sc(6), sy + sc(16) }, { sx + sw - sc(6), sy + sc(16) }, { sx + sc(6), sy + sh - sc(16) }, { sx + sw - sc(6), sy + sh - sc(16) } }) do
			draw.SimpleText("+", "SardonMatbaa.Body", p[1], p[2], C_107_98_62, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end

		local f = state.format
		local px, py, pw, ph = paperRect(f, sx + sc(30), sy + sc(26), sw - sc(60), sh - sc(52))

		-- genişlik ölçüsü (üstte, çizgilerle)
		local lbl = f.genislik .. " px"
		local lw = textWidth(lbl, "SardonMatbaa.Caption", 1)
		local ly = py - sc(14)

		spaced(lbl, "SardonMatbaa.Caption", px + pw / 2, ly, C_156_149_126, 1, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		surface.SetDrawColor(108, 98, 65, 110)
		surface.DrawLine(px + pw / 2 - lw / 2 - sc(52), ly, px + pw / 2 - lw / 2 - sc(10), ly)
		surface.DrawLine(px + pw / 2 + lw / 2 + sc(10), ly, px + pw / 2 + lw / 2 + sc(52), ly)

		-- yükseklik ölçüsü (sağda, çizgilerle)
		local vx, vy = px + pw + sc(18), py + ph / 2

		draw.SimpleText(f.yukseklik, "SardonMatbaa.Caption", vx, vy - sc(7), C_156_149_126, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		draw.SimpleText("px", "SardonMatbaa.Caption", vx, vy + sc(7), C_156_149_126, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		surface.SetDrawColor(108, 98, 65, 110)
		surface.DrawLine(vx, vy - sc(62), vx, vy - sc(20))
		surface.DrawLine(vx, vy + sc(20), vx, vy + sc(62))

		drawPaper(f, px, py, pw, ph)

		spaced("PRUEBA DIGITAL", "SardonMatbaa.Caption", w / 2, sy + sh - sc(6), C_140_137_111, 2, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)

		-- seçili format bilgisi
		local iy = sy + sh + sc(20)

		surface.SetDrawColor(T.borderSoft)
		surface.DrawLine(ix, iy, w - ix, iy)

		spaced("FORMATO ELEGIDO", "SardonMatbaa.Caption", ix, iy + sc(26), C_155_155_133, 1.3, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText(f.ad, "SardonMatbaa.Big", ix, iy + sc(52), T.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		local pill = f.genislik .. " × " .. f.yukseklik .. " px"
		local pwid = textWidth(pill, "SardonMatbaa.Label") + sc(18)
		local pillY = iy + sc(30)

		surface.SetDrawColor(198, 161, 91, 8)
		surface.DrawRect(w - ix - pwid, pillY, pwid, sc(30))
		surface.SetDrawColor(T.borderSoft)
		surface.DrawOutlinedRect(w - ix - pwid, pillY, pwid, sc(30), 1)
		draw.SimpleText(pill, "SardonMatbaa.Label", w - ix - pwid / 2, pillY + sc(15), T.goldBright, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		-- not
		local ny = iy + sc(84)
		icon("info", ix, ny, sc(15), C_167_146_96)
		draw.SimpleText("Se conserva la imagen completa.", "SardonMatbaa.Small", ix + sc(24), ny, C_167_167_148, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		draw.SimpleText("Los huecos se rellenan con color de papel.", "SardonMatbaa.Small", ix + sc(24), ny + sc(19), C_167_167_148, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		if f.aciklama then
			draw.SimpleText(f.aciklama .. (f.asilabilir and " Se puede colgar en la pared." or ""), "SardonMatbaa.Small", ix + sc(24), ny + sc(38), T.faint, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		end

		-- alt durum satırı
		local st, col = "Introduce un enlace para la vista previa", C_180_182_152
		local ist = imageState()

		if ist == "ok" then st, col = "Imagen cargada", T.success
		elseif ist == "fail" then st, col = "No se pudo cargar la imagen", T.danger
		elseif ist == "loading" then st = "Cargando imagen…" end

		local by = h - sc(24)
		local sw2 = textWidth(st, "SardonMatbaa.Tiny")

		draw.SimpleText(st, "SardonMatbaa.Tiny", w / 2, by, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		diamond(w / 2 - sw2 / 2 - sc(14), by, sc(3), C_144_123_71)
		diamond(w / 2 + sw2 / 2 + sc(14), by, sc(3), C_144_123_71)
	end

	-- büyük önizleme
	local function openZoom()
		if IsValid(root.zoom) then root.zoom:Remove() end

		local z = vgui.Create("DButton", root)
		z:SetText("")
		z:SetSize(ScrW(), ScrH())
		z:SetAlpha(0)
		z:AlphaTo(255, 0.15)
		z.DoClick = function(self) self:Remove() end
		root.zoom = z

		function z:Paint(w, h)
			surface.SetDrawColor(4, 6, 5, 225)
			surface.DrawRect(0, 0, w, h)

			local f = state.format
			local px, py, pw, ph = paperRect(f, sc(60), sc(90), w - sc(120), h - sc(170))

			spaced("VISTA PREVIA", "SardonMatbaa.Section", w / 2, sc(50), T.goldBright, 1.4, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			drawPaper(f, px, py, pw, ph, true)
			draw.SimpleText(f.ad .. " · " .. f.genislik .. " × " .. f.yukseklik .. " px", "SardonMatbaa.Label", w / 2, h - sc(50), T.muted, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			draw.SimpleText("Clic o ESC para cerrar", "SardonMatbaa.Tiny", w / 2, h - sc(28), T.faint, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
	end

	local expand = makeButton(preview, "", openZoom, { icon = "eye" })
	expand:SetSize(sc(30), sc(30))
	expand:SetPos(leftW - sc(20) - sc(30), sc(13))
	expand:SetTooltip("Ampliar vista previa")

	-- ------------- SAĞ: AYARLAR -------------
	local fixedH = sc(156) -- adet/maliyet + baskı düğmesi + ipucu satırı (kaydırılmaz)

	local scroll = vgui.Create("DScrollPanel", win)
	scroll:SetPos(rx, top)
	scroll:SetSize(RW, bottom - top - fixedH)

	local vbar = scroll:GetVBar()
	vbar:SetWide(sc(6))
	vbar:SetHideButtons(true)
	function vbar:Paint(w, h) surface.SetDrawColor(T.borderFaint) surface.DrawRect(w / 2 - 1, 0, 2, h) end
	function vbar.btnGrip:Paint(w, h) surface.SetDrawColor(T.gold) surface.DrawRect(1, 0, w - 2, h) end

	local canvas = scroll:GetCanvas()
	canvas:DockPadding(0, 0, sc(10), sc(4))

	local function block(h, marginBottom)
		local p = vgui.Create("DPanel", canvas)
		p:Dock(TOP)
		p:SetTall(h)
		p:DockMargin(0, 0, 0, marginBottom or 0)
		p.Paint = nil

		return p
	end

	-- --- 01 MATERIALES ---
	sectionTitle(canvas, "01", "MATERIALES", "MOCHILA  ·  IMPRENTA")

	local function transferOK()
		return CurTime() > state.lastTransfer + 0.35
	end

	local function materialRow(label, uniqueID, key, iconName)
		local row = block(sc(58), sc(8))

		function row:Paint(w, h)
			surface.SetDrawColor(25, 32, 23, 140)
			surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(104, 91, 53, 70)
			surface.DrawOutlinedRect(0, 0, w, h, 1)

			local bs = sc(40)
			local bx, by = sc(13), (h - bs) / 2

			surface.SetDrawColor(131, 112, 63, 80)
			surface.DrawOutlinedRect(bx, by, bs, bs, 1)
			icon(iconName, bx + sc(8), by + sc(8), bs - sc(16), T.gold)

			local tx = bx + bs + sc(14)
			draw.SimpleText(label, "SardonMatbaa.Body", tx, h / 2 - sc(10), T.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			local x = tx
			x = x + draw.SimpleText("En máquina ", "SardonMatbaa.Small", x, h / 2 + sc(12), C_162_165_142, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			x = x + draw.SimpleText(stock()[key], "SardonMatbaa.Value", x, h / 2 + sc(12), C_223_214_184, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			x = x + draw.SimpleText("  ·  ", "SardonMatbaa.Small", x, h / 2 + sc(12), C_114_118_94, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			x = x + draw.SimpleText("En mochila ", "SardonMatbaa.Small", x, h / 2 + sc(12), C_162_165_142, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			draw.SimpleText(invCount(uniqueID), "SardonMatbaa.Value", x, h / 2 + sc(12), C_223_214_184, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end

		local function send(netName, amount)
			state.lastTransfer = CurTime()

			net.Start(netName)
				net.WriteEntity(machine)
				net.WriteUInt(key == "ink" and amount or 0, 16)
				net.WriteUInt(key == "paper" and amount or 0, 16)
			net.SendToServer()
		end

		local hasInv = function() return transferOK() and invCount(uniqueID) > 0 end
		local hasStock = function() return transferOK() and stock()[key] > 0 end

		local buttons = {
			{ "Depositar 1", function() send("SardonMatbaa.Deposit", 1) end, hasInv, 54 },
			{ "Depositar todo", function() send("SardonMatbaa.Deposit", math.min(invCount(uniqueID), 65535)) end, hasInv, 88 },
			false,
			{ "Retirar 1", function() send("SardonMatbaa.Withdraw", 1) end, hasStock, 46 },
			{ "Retirar todo", function() send("SardonMatbaa.Withdraw", math.min(stock()[key], 65535)) end, hasStock, 80 },
		}

		local bh = sc(30)
		local ctrls = {}

		for i, b in ipairs(buttons) do
			if b then
				local btn = makeButton(row, b[1], b[2], { enabled = b[3] })
				btn:SetSize(sc(b[4]), bh)
				ctrls[i] = btn
			else
				-- Koy / Al grupları arasındaki dikey çizgi
				local sep = vgui.Create("DPanel", row)
				sep:SetSize(sc(9), bh)
				function sep:Paint(w, h) surface.SetDrawColor(115, 99, 67, 80) surface.DrawLine(w / 2, h * 0.2, w / 2, h * 0.8) end
				ctrls[i] = sep
			end
		end

		-- kaydırma çubuğu açılınca satır daralır; butonlar gerçek genişliğe göre sağa yaslanır
		function row:PerformLayout(w, h)
			local x = w - sc(13)

			for i = #ctrls, 1, -1 do
				x = x - ctrls[i]:GetWide()
				ctrls[i]:SetPos(x, (h - bh) / 2)
				x = x - sc(5)
			end
		end
	end

	materialRow("Tinta", SardonMatbaa.INK, "ink", "ink")
	materialRow("Papel en blanco", SardonMatbaa.PAPER, "paper", "paper")

	block(sc(6))

	-- --- 02 FORMATO DE IMPRESIÓN ---
	sectionTitle(canvas, "02", "FORMATO DE IMPRESIÓN", #formats .. " OPCIONES")

	local cols = 2
	local cgap = sc(10)
	local ch = sc(74)
	local rows = math.ceil(#formats / cols)
	local grid = block(rows * ch + (rows - 1) * cgap + sc(6), sc(14))

	local function layoutCards()
		local cw = (grid:GetWide() - cgap * (cols - 1)) / cols

		for i, card in ipairs(grid.cards or {}) do
			card:SetSize(cw, ch)
			card:SetPos(((i - 1) % cols) * (cw + cgap), sc(6) + math.floor((i - 1) / cols) * (ch + cgap))
		end
	end

	grid.PerformLayout = layoutCards
	grid.cards = {}

	for _, f in ipairs(formats) do
		local card = vgui.Create("DButton", grid)
		card:SetText("")
		grid.cards[#grid.cards + 1] = card

		card.DoClick = function()
			surface.PlaySound("ui/buttonclick.wav")
			state.format = f
			SardonMatbaa.LastFormat = f.id
			state.copies = math.Clamp(state.copies, 1, math.max(1, maxCopies()))
		end

		function card:Paint(w, h)
			local sel = state.format == f
			local hov = self:IsHovered()
			local inkCost, papCost = SardonMatbaa.GetCost(f)
			local can = maxCopies(f)

			surface.SetDrawColor(sel and C_50_46_28_140 or (hov and C_34_40_27_230 or C_23_30_22_170))
			surface.DrawRect(0, 0, w, h)

			if sel then
				surface.SetDrawColor(180, 148, 72, 30)
				surface.SetMaterial(matGradR)
				surface.DrawTexturedRectUV(0, 0, w, h, 1, 0, 0, 1)
			end

			surface.SetDrawColor(sel and C_210_173_96 or (hov and C_172_142_80 or C_106_91_58_140))
			surface.DrawOutlinedRect(0, 0, w, h, sel and 2 or 1)

			local is = sc(30)
			icon(formatIcon(f), sc(14), h / 2 - is / 2, is, sel and T.goldBright or C_148_140_105)

			local tx = sc(14) + is + sc(14)
			draw.SimpleText(f.ad, "SardonMatbaa.Body", tx, h / 2 - sc(13), T.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			draw.SimpleText(f.genislik .. " × " .. f.yukseklik, "SardonMatbaa.Tiny", w - (sel and sc(40) or sc(14)), h / 2 - sc(13), C_170_165_138, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
			draw.SimpleText(inkCost .. " tinta + " .. papCost .. " papel", "SardonMatbaa.Small", tx, h / 2 + sc(15), C_165_165_141, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			draw.SimpleText(can > 0 and (can .. " copias posibles") or "Material insuficiente", "SardonMatbaa.Tiny", w - sc(14), h / 2 + sc(15), can > 0 and T.success or T.danger, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

			if sel then
				local r = sc(8)
				local cx, cy = w - sc(10) - r * 2, sc(6)
				draw.RoundedBox(r, cx, cy, r * 2, r * 2, C_215_179_107)
				icon("check", cx + sc(3), cy + sc(3), r * 2 - sc(6), T.ink)
			end
		end
	end

	-- --- 03 ENLACE DE IMAGEN ---
	sectionTitle(canvas, "03", "ENLACE DE IMAGEN", "PNG · JPG")

	local urlRow = block(sc(42), sc(8))

	local wrap = vgui.Create("DPanel", urlRow)
	wrap:Dock(FILL)
	wrap:DockMargin(0, 0, sc(9), 0)
	wrap:DockPadding(sc(38), 0, sc(10), 0)

	local entry = vgui.Create("DTextEntry", wrap)
	entry:Dock(FILL)
	entry:SetFont("SardonMatbaa.Label")
	entry:SetPlaceholderText("https://i.imgur.com/ejemplo.png")
	entry:SetDrawLanguageID(false)
	entry:SetPaintBackground(false)
	entry:SetUpdateOnType(true)

	function wrap:Paint(w, h)
		surface.SetDrawColor(T.inset)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(entry:HasFocus() and T.gold or C_125_107_67_150)
		surface.DrawOutlinedRect(0, 0, w, h, 1)
		icon("link", sc(13), h / 2 - sc(8), sc(16), C_152_131_84)
	end

	function entry:Paint(w, h)
		if self:GetText() == "" and !self:HasFocus() then
			draw.SimpleText(self:GetPlaceholderText(), "SardonMatbaa.Label", 3, h / 2, C_127_132_111, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end

		self:DrawTextEntryText(T.text, T.goldDim, T.text)
	end

	local function applyURL()
		local value = entry:GetValue()
		local url, err = SardonMatbaa.ValidateURL(value)

		state.url = url
		state.urlError = (string.Trim(value) != "" and err) or nil

		-- Daha önce başarısız olan bağlantıyı yeniden denemeye izin ver
		if url and SardonMatbaa.ImageCache[url] and SardonMatbaa.ImageCache[url].state == "fail" then
			SardonMatbaa.ImageCache[url] = nil
		end

		if url then SardonMatbaa.GetMaterial(url) end
	end

	entry.OnEnter = applyURL
	-- Yazarken eski önizleme/doğrulama geçersiz; Enter / Vista previa ile yeniden doğrulanır
	entry.OnValueChange = function()
		state.url = nil
		state.urlError = nil
	end

	local previewBtn = makeButton(urlRow, "Vista previa", applyURL, { icon = "eye", font = "SardonMatbaa.Label" })
	previewBtn:Dock(RIGHT)
	previewBtn:SetWide(sc(110))

	local urlInfo = block(sc(40), 0)

	function urlInfo:Paint(w, h)
		local text, col
		local ist = imageState()

		if state.urlError then
			text, col = state.urlError, T.danger
		elseif ist == "ok" then
			text, col = "Enlace válido; imagen lista.", T.success
		elseif ist == "fail" then
			text, col = "Enlace permitido pero la imagen falló; puede estar caducada o rota.", T.danger
		elseif ist == "loading" then
			text, col = "Cargando imagen…", T.gold
		else
			text, col = "Enlace directo .png / .jpg · Enter o Vista previa para validar", C_145_153_131
		end

		draw.SimpleText(text, "SardonMatbaa.Small", 0, sc(9), col, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText("Sitios permitidos: " .. table.concat(cfg.IzinliAlanlar, " · "), "SardonMatbaa.Tiny", 0, sc(29), C_146_149_129, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end

	-- ------------- SABİT: COPIAS + COSTE TOTAL -------------
	local order = vgui.Create("DPanel", win)
	order:SetPos(rx, bottom - fixedH)
	order:SetSize(RW, sc(64))

	function order:Paint(w, h)
		surface.SetDrawColor(128, 106, 63, 100)
		surface.DrawLine(0, 0, w, 0)

		spaced("NÚMERO DE COPIAS", "SardonMatbaa.Caption", 0, sc(15), C_205_183_131, 1, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		spaced("COSTE TOTAL", "SardonMatbaa.Caption", w, sc(15), C_205_183_131, 1, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

		local inkCost, papCost = SardonMatbaa.GetCost(state.format)
		local n = maxCopies() > 0 and state.copies or 0
		local cy = sc(45)
		local is = sc(14)

		-- sağdan sola: [ikon] N papel  +  [ikon] N mürekkep
		local x = w
		x = x - draw.SimpleText(" papel", "SardonMatbaa.Label", x, cy, T.text, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		x = x - draw.SimpleText(papCost * n, "SardonMatbaa.Value", x, cy, T.goldBright, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		x = x - is - sc(6)
		icon("paper", x, cy - is / 2, is, T.gold)
		x = x - sc(12)
		x = x - draw.SimpleText("+", "SardonMatbaa.Label", x, cy, T.goldDim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER) - sc(12)
		x = x - draw.SimpleText(" tinta", "SardonMatbaa.Label", x, cy, T.text, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		x = x - draw.SimpleText(inkCost * n, "SardonMatbaa.Value", x, cy, T.goldBright, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		x = x - is - sc(6)
		icon("ink", x, cy - is / 2, is, T.gold)

		-- süre
		x = x - sc(22)
		x = x - draw.SimpleText(fmtTime(SardonMatbaa.GetDuration(math.max(1, n))), "SardonMatbaa.Label", x, cy, T.muted, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		icon("clock", x - is - sc(6), cy - is / 2, is, T.goldDim)
	end

	local function setCopies(n)
		state.copies = math.Clamp(math.floor(tonumber(n) or 1), 1, math.max(1, maxCopies()))
	end

	local qh = sc(34)
	local qy = sc(45) - qh / 2
	local hasCopies = function() return maxCopies() > 0 end

	local minus = makeButton(order, "", function() setCopies(state.copies - (input.IsShiftDown() and 5 or 1)) end, { icon = "minus", enabled = function() return hasCopies() and state.copies > 1 end })
	minus:SetSize(qh, qh)
	minus:SetPos(0, qy)

	local qty = vgui.Create("DTextEntry", order)
	qty:SetPos(qh + sc(5), qy)
	qty:SetSize(sc(46), qh)
	qty:SetFont("SardonMatbaa.Qty")
	qty:SetNumeric(true)
	qty:SetDrawLanguageID(false)
	qty:SetPaintBackground(false)
	qty:SetText("1")

	function qty:Paint(w, h)
		surface.SetDrawColor(T.inset)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(self:HasFocus() and T.gold or C_128_107_62)
		surface.DrawOutlinedRect(0, 0, w, h, 1)

		if !self:HasFocus() then
			draw.SimpleText(hasCopies() and state.copies or 0, "SardonMatbaa.Qty", w / 2, h / 2, C_232_213_172, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		else
			self:DrawTextEntryText(T.text, T.goldDim, T.text)
		end
	end

	local function commitQty()
		setCopies(qty:GetValue())
		qty:SetText(tostring(state.copies))
	end

	qty.OnEnter = commitQty
	qty.OnLoseFocus = function(self)
		commitQty()
		vgui.GetControlTable("DTextEntry").OnLoseFocus(self)
	end
	qty.OnGetFocus = function(self)
		self:SetText(tostring(state.copies))
		self:SelectAllText(true)
		vgui.GetControlTable("DTextEntry").OnGetFocus(self)
	end
	function qty:OnMouseWheeled(delta) setCopies(state.copies + delta) return true end

	local plus = makeButton(order, "", function() setCopies(state.copies + (input.IsShiftDown() and 5 or 1)) end, { icon = "plus", enabled = function() return hasCopies() and state.copies < maxCopies() end })
	plus:SetSize(qh, qh)
	plus:SetPos(qh + sc(56), qy)

	local maxBtn = makeButton(order, function() return "Máximo  " .. maxCopies() end, function() setCopies(maxCopies()) end, { enabled = hasCopies })
	maxBtn:SetSize(sc(92), qh)
	maxBtn:SetPos(qh * 2 + sc(61), qy)

	-- ------------- SABİT: BASKI DÜĞMESİ -------------
	local printBtn = vgui.Create("DButton", win)
	printBtn:SetText("")
	printBtn:SetPos(rx, bottom - fixedH + sc(74))
	printBtn:SetSize(RW, sc(52))

	printBtn.DoClick = function()
		if !canPrint() then return end

		surface.PlaySound("ui/buttonclick.wav")
		state.sentAt = CurTime()

		net.Start("SardonMatbaa.Print")
			net.WriteEntity(machine)
			net.WriteString(state.format.id)
			net.WriteString(state.url)
			net.WriteUInt(state.copies, 8)
		net.SendToServer()
	end

	function printBtn:Paint(w, h)
		local enabled = canPrint()
		local hov = enabled and self:IsHovered()

		if busy() then
			-- baskı sürüyor: makinenin iş süresinden ilerleme
			local s, e = machine:GetJobStart(), machine:GetJobEnd()
			local frac = e > s and math.Clamp((CurTime() - s) / (e - s), 0, 1) or 0

			surface.SetDrawColor(T.inset)
			surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(160, 128, 66, 200)
			surface.DrawRect(0, 0, w * frac, h)
			surface.SetDrawColor(T.gold)
			surface.DrawOutlinedRect(0, 0, w, h, 1)

			local label = (myJob() and "IMPRIMIENDO" or "MÁQUINA OCUPADA") .. "  ·  " .. machine:GetJobCopies() .. " × " .. machine:GetJobFormat() .. "  ·  " .. fmtTime(e - CurTime())
			spaced(label, "SardonMatbaa.Print", w / 2, h / 2, T.goldBright, 2, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			return
		end

		if enabled then
			surface.SetDrawColor(hov and C_214_178_106 or T.gold)
			surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(240, 214, 154, hov and 200 or 150)
			surface.SetMaterial(matGradR)
			surface.DrawTexturedRectUV(0, 0, w * 0.7, h, 1, 0, 0, 1)
			surface.SetDrawColor(255, 240, 200, 60)
			surface.DrawOutlinedRect(0, 0, w, h, 1)
		else
			surface.SetDrawColor(52, 54, 44)
			surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(T.disabled)
			surface.DrawOutlinedRect(0, 0, w, h, 1)
		end

		local fg = enabled and T.ink or C_120_122_104
		local label = CurTime() <= state.sentAt + 3 and "ENVIANDO…" or "INICIAR IMPRESIÓN"
		local count = (hasCopies() and state.copies or 0) .. " COPIAS"
		local is = sc(22)
		local lw = textWidth(label, "SardonMatbaa.Print", 2.5)
		local cw = textWidth(count, "SardonMatbaa.Caption", 1)
		local total = is + sc(14) + lw + sc(26) + cw
		local x = w / 2 - total / 2

		icon("print", x, h / 2 - is / 2, is, fg)
		x = x + is + sc(14)
		spaced(label, "SardonMatbaa.Print", x, h / 2, fg, 2.5, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		x = x + lw + sc(13)
		surface.SetDrawColor(fg.r, fg.g, fg.b, 110)
		surface.DrawLine(x, h * 0.32, x, h * 0.68)
		spaced(count, "SardonMatbaa.Caption", x + sc(13), h / 2, fg, 1, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		icon("arrow-in", w - sc(26) - sc(18), h / 2 - sc(9), sc(18), fg)
	end

	local hint = vgui.Create("DPanel", win)
	hint:SetPos(rx, bottom - fixedH + sc(132))
	hint:SetSize(RW, sc(22))

	function hint:Paint(w, h)
		local text, col, ic = nil, T.danger, "info"
		local m = maxCopies()
		local ist = imageState()

		if busy() then
			if myJob() then
				text, col, ic = "Impresión en curso. Puedes cerrar el panel; la caja aparecerá delante de la máquina cuando esté lista.", T.gold, "clock"
			else
				text, col, ic = "La máquina está imprimiendo para " .. machine:GetJobOwner() .. ". Espera a que termine.", T.gold, "clock"
			end
		elseif m <= 0 then
			local inkCost, papCost = SardonMatbaa.GetCost(state.format)
			text = "Material insuficiente: 1 × " .. state.format.ad .. " necesita " .. inkCost .. " tinta + " .. papCost .. " papel."
		elseif !state.url then
			text, col = state.urlError and "Introduce un enlace de imagen válido." or "Introduce el enlace y previsualiza.", state.urlError and T.danger or T.muted
		elseif ist == "loading" then
			text, col, ic = "Cargando imagen, espera…", T.gold, "clock"
		elseif ist == "fail" then
			text = "No se pudo cargar la imagen; prueba con otro enlace."
		else
			text, col, ic = "Materiales listos. Puedes imprimir.", T.success, "check"
		end

		local tw = textWidth(text, "SardonMatbaa.Small")
		local is = sc(13)
		local x = w / 2 - (tw + is + sc(8)) / 2

		icon(ic, x, h / 2 - is / 2, is, col)
		draw.SimpleText(text, "SardonMatbaa.Small", x + is + sc(8), h / 2, col, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end
end

net.Receive("SardonMatbaa.Open", function()
	local machine = net.ReadEntity()
	local ink = net.ReadUInt(16)
	local paper = net.ReadUInt(16)

	if IsValid(machine) then
		SardonMatbaa.OpenMenu(machine, ink, paper)
	end
end)

net.Receive("SardonMatbaa.Stock", function()
	SardonMatbaa.ClientStock.ink = net.ReadUInt(16)
	SardonMatbaa.ClientStock.paper = net.ReadUInt(16)
end)
