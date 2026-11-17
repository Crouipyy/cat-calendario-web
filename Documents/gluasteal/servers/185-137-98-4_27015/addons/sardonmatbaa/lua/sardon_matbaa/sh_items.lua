-- "addons\\sardonmatbaa\\lua\\sardon_matbaa\\sh_items.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Matbaa itemleri: hammaddeler (mürekkep, boş kağıt), her format için bir basılı item
-- ve baskı işinin çıktığı kutu (gerçek bir Helix çantası, bkz. base_bags).
local cfg = SardonMatbaa.Config

-- ============= HAMMADDELER =============
do
	local ITEM = ix.item.Register(SardonMatbaa.INK, nil, false, nil, true)

	ITEM.name = "Tinta de imprenta"
	ITEM.description = "Frasco de tinta densa para la máquina de impresión. Se deposita en la máquina o desde el panel."
	ITEM.model = cfg.MurekkepModel
	ITEM.width = 1
	ITEM.height = 1
	ITEM.category = cfg.Kategori
end

do
	local ITEM = ix.item.Register(SardonMatbaa.PAPER, nil, false, nil, true)

	ITEM.name = "Papel en blanco"
	ITEM.description = "Hoja lista para imprimir. Se deposita en la máquina o desde el panel."
	ITEM.model = cfg.KagitModel
	ITEM.width = 1
	ITEM.height = 1
	ITEM.category = cfg.Kategori
end

-- ============= BASILI ÜRÜNLER =============
local function validOwner(item)
	return !IsValid(item.entity) and IsValid(item.player or item:GetOwner())
end

local function printFunctions(ITEM)
	ITEM.functions.matbaaGoruntule = {
		name = "Ver",
		icon = "icon16/zoom.png",
		OnClick = function(item)
			if SardonMatbaa.OpenViewer then
				SardonMatbaa.OpenViewer(item:GetData("url"), item:GetFormat().ad, item:GetData("basan"))
			end

			return false
		end,
		OnRun = function() return false end,
		OnCanRun = function(item) return !IsValid(item.entity) end
	}

	ITEM.functions.matbaaGoster = {
		name = "Mostrar al de enfrente",
		icon = "icon16/user_go.png",
		OnRun = function(item)
			if SERVER and SardonMatbaa.ShowToTarget then
				SardonMatbaa.ShowToTarget(item.player, item)
			end

			return false
		end,
		OnCanRun = validOwner
	}

	ITEM.functions.matbaaAs = {
		name = "Colgar en la pared",
		icon = "icon16/picture_add.png",
		OnRun = function(item)
			if SERVER and SardonMatbaa.HangPoster then
				SardonMatbaa.HangPoster(item.player, item)
			end

			return false
		end,
		OnCanRun = function(item)
			local format = item:GetFormat()

			return validOwner(item) and format != nil and format.asilabilir == true
		end
	}

	ITEM.functions.matbaaKopyala = {
		name = "Copiar enlace",
		icon = "icon16/picture_link.png",
		OnClick = function(item)
			SetClipboardText(item:GetData("url", ""))
			LocalPlayer():Notify("Enlace copiado al portapapeles.")

			return false
		end,
		OnRun = function() return false end,
		OnCanRun = function(item) return !IsValid(item.entity) end
	}

	ITEM.functions.matbaaYirt = {
		name = "Rasgar",
		icon = "icon16/cut_red.png",
		OnRun = function(item)
			local client = item.player

			if IsValid(client) then
				client:EmitSound("physics/cardboard/cardboard_box_break" .. math.random(1, 3) .. ".wav", 60, math.random(120, 140), 0.6)
			end

			return true
		end,
		OnCanRun = validOwner
	}

	-- Helix'in genel ix_item prop'u yerine üzerinde görseli çizen kendi entity'miz düşüyor;
	-- bu entity polaroid masasına/projektörüne çarpınca görseli onlara aktarır.
	ITEM.functions.drop = {
		tip = "dropTip",
		icon = "icon16/world.png",
		OnRun = function(item)
			local client = item.player

			if !IsValid(client) then return false end

			local ent = ents.Create("ent_matbaa_print")

			if !IsValid(ent) then return false end

			ent:SetURL(item:GetData("url", ""))
			ent:SetFormat(item.matbaaFormat)
			ent:SetPrinter(item:GetData("basan", ""))
			ent:SetPos(client:GetItemDropPos(ent) + Vector(0, 0, 5))
			ent:SetAngles(Angle(0, client:EyeAngles().y + 180, 0))
			ent:Spawn()

			local phys = ent:GetPhysicsObject()
			if IsValid(phys) then phys:Wake() end

			client:EmitSound("npc/zombie/foot_slide" .. math.random(1, 3) .. ".wav", 75, math.random(90, 120), 1)

			return true
		end,
		OnCanRun = function(item)
			return !IsValid(item.entity) and !item.noDrop
		end
	}
end

for _, format in ipairs(cfg.Formatlar) do
	local ITEM = ix.item.Register(format.item, nil, false, nil, true)

	ITEM.name = format.ad
	ITEM.description = format.aciklama
	ITEM.model = format.model or cfg.KagitModel
	ITEM.width = 1
	ITEM.height = 1
	ITEM.category = cfg.Kategori
	ITEM.matbaaFormat = format.id
	ITEM.isMatbaaPrint = true

	function ITEM:GetFormat()
		return SardonMatbaa.GetFormat(self.matbaaFormat)
	end

	function ITEM:GetDescription()
		local desc = self.description
		local by = self:GetData("basan")
		local date = self:GetData("tarih")

		if by and by != "" then desc = desc .. "\nImpreso por: " .. by end
		if date then desc = desc .. "\nFecha: " .. os.date("%d.%m.%Y", date) end

		return desc
	end

	printFunctions(ITEM)

	if CLIENT then
		local col_bg = Color(0, 0, 0, 160)

		-- Envanter karesinde görselin küçük bir önizlemesi
		function ITEM:PaintOver(item, w, h)
			if !SardonMatbaa.GetMaterial then return end

			local mat = SardonMatbaa.GetMaterial(item:GetData("url"))

			if !mat then return end

			local pad = 4
			local bw, bh = w - pad * 2, h - pad * 2

			surface.SetDrawColor(col_bg)
			surface.DrawRect(pad, pad, bw, bh)
			SardonMatbaa.DrawFit(mat, pad, pad, bw, bh)
		end
	end
end

-- ============= KUTU =============
do
	local ITEM = ix.item.Register(SardonMatbaa.BOX, "base_bags", false, nil, true)

	ITEM.name = "Caja de imprenta"
	ITEM.description = "Caja de cartón con las copias impresas de la máquina."
	ITEM.model = cfg.KutuModel
	ITEM.category = cfg.Kategori
	ITEM.width = 2
	ITEM.height = 2
	ITEM.invWidth = cfg.KutuGenislik
	ITEM.invHeight = cfg.KutuYukseklik

	-- base_bags'in OnRegistered'ı Register sırasında 6x6 ile çalıştı -- kendi boyutumuzla yeniden kaydet.
	ix.inventory.Register(SardonMatbaa.BOX, ITEM.invWidth, ITEM.invHeight, true)

	function ITEM:GetName()
		local label = self:GetData("etiket")

		return label and ("Caja de imprenta (" .. label .. ")") or "Caja de imprenta"
	end

	ITEM.functions.matbaaHepsiniAl = {
		name = "Vaciar caja",
		icon = "icon16/basket_remove.png",
		OnRun = function(item)
			if SERVER and SardonMatbaa.EmptyBox then
				SardonMatbaa.EmptyBox(item.player, item)
			end

			return false
		end,
		OnCanRun = function(item)
			local inv = item:GetInventory()

			return !IsValid(item.entity) and inv != nil and !table.IsEmpty(inv:GetItems())
		end
	}

	if CLIENT then
		function ITEM:PopulateTooltip(tooltip)
			local by = self:GetData("sahipAd")

			if by then
				local row = tooltip:AddRow("matbaaSahip")
				row:SetText("Pedido de: " .. by)
				row:SetBackgroundColor(Color(120, 90, 40))
				row:SizeToContents()
			end
		end
	end
end

-- Kutuya sadece basılı ürün konabilir (kutu içinde kutu, hammadde vb. olmaz)
hook.Add("CanTransferItem", "SardonMatbaa.BoxFilter", function(item, oldInv, newInv)
	if !newInv or !newInv.vars or newInv.vars.isBag != SardonMatbaa.BOX then return end

	if !item.isMatbaaPrint then
		return false
	end
end)
