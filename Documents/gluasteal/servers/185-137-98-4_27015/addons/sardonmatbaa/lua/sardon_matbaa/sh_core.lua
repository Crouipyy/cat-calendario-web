-- "addons\\sardonmatbaa\\lua\\sardon_matbaa\\sh_core.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Ortak yardımcılar: format tablosu, maliyet hesabı, URL doğrulama.
SardonMatbaa = SardonMatbaa or {}

local cfg = SardonMatbaa.Config

SardonMatbaa.INK = "matbaa_murekkep"
SardonMatbaa.PAPER = "matbaa_kagit"
SardonMatbaa.BOX = "matbaa_kutu"

SardonMatbaa.FormatByID = {}

for i, f in ipairs(cfg.Formatlar) do
	f.index = i
	f.item = "matbaa_baski_" .. f.id
	SardonMatbaa.FormatByID[f.id] = f
end

function SardonMatbaa.GetFormat(id)
	return SardonMatbaa.FormatByID[id]
end

-- Bir kopya için gereken mürekkep ve kağıt
function SardonMatbaa.GetCost(format)
	if isstring(format) then format = SardonMatbaa.FormatByID[format] end
	if not format then return 0, 0 end

	local ink = format.murekkep

	if not ink then
		local over = math.max(0, math.max(format.genislik, format.yukseklik) - cfg.TabanPx)
		ink = cfg.TabanMurekkep + math.ceil(over / cfg.PxAdimi) * cfg.AdimMurekkep
	end

	return ink, format.kagit or 1
end

-- Eldeki stokla en fazla kaç kopya basılabilir
function SardonMatbaa.GetMaxCopies(format, ink, paper)
	local needInk, needPaper = SardonMatbaa.GetCost(format)
	local byInk = needInk > 0 and math.floor(ink / needInk) or cfg.MaksAdet
	local byPaper = needPaper > 0 and math.floor(paper / needPaper) or cfg.MaksAdet

	return math.max(0, math.min(byInk, byPaper, cfg.MaksAdet))
end

function SardonMatbaa.GetDuration(copies)
	return cfg.SabitSure + copies * cfg.AdetBasinaSure
end

-- Beyaz liste kontrolü. Başarılıysa temizlenmiş URL'yi döndürür, değilse nil + sebep.
function SardonMatbaa.ValidateURL(url)
	if not isstring(url) then return nil, "Enlace no válido." end

	url = string.Trim(url)

	if #url > 512 then return nil, "El enlace es demasiado largo." end
	if url:find("[%s\"'<>\\]") then return nil, "El enlace contiene caracteres no válidos." end

	local host, path = url:match("^https://([%w%.%-]+)(/[^?#]*)")

	if not host then return nil, "El enlace debe ser https:// y apuntar directamente a una imagen." end

	host = host:lower()

	local allowed = false

	for _, domain in ipairs(cfg.IzinliAlanlar) do
		if host == domain or host:sub(-(#domain + 1)) == "." .. domain then
			allowed = true
			break
		end
	end

	if not allowed then
		return nil, "Este sitio no está permitido. Sitios permitidos: " .. table.concat(cfg.IzinliAlanlar, ", ")
	end

	local ext = path:match("%.(%w+)$")

	if not ext or not cfg.IzinliUzantilar[ext:lower()] then
		return nil, "El enlace debe terminar en .png o .jpg."
	end

	return url
end

-- Polaroid'in eski iili.io kodlarını (http'siz) da tam URL'ye çevirir
function SardonMatbaa.ResolveImage(image)
	if not isstring(image) or image == "" then return nil end
	if image:sub(1, 8) == "https://" then return image end

	return "https://iili.io/" .. image .. ".png"
end
