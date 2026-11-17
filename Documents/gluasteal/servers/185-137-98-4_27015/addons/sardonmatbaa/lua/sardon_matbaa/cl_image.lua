-- "addons\\sardonmatbaa\\lua\\sardon_matbaa\\cl_image.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- URL'den görsel yükleme + önbellek. Önce doğrudan, olmazsa DuckDuckGo proxy'si ile
-- (polaroid'in kullandığı yol) indirilir; dosyanın ilk baytlarına bakılarak png/jpg
-- ayrılır, data/sardon_matbaa/img altına yazılıp Material olarak açılır.
-- NOT: istemcide cl_ dosyaları sh_ dosyalarından önce yükleniyor -- bu dosya kapsamında
-- SardonMatbaa.Config okunmamalı.
SardonMatbaa = SardonMatbaa or {}

local DIR = "sardon_matbaa/img"
local MAX_BYTES = 8 * 1024 * 1024

file.CreateDir(DIR)

-- [url] = { state = "loading" | "ok" | "fail", mat = IMaterial }
SardonMatbaa.ImageCache = SardonMatbaa.ImageCache or {}
local cache = SardonMatbaa.ImageCache

local function urlEncode(s)
	return (s:gsub("[^%w%-%._~]", function(c) return string.format("%%%02X", string.byte(c)) end))
end

local function sniff(body)
	if body:sub(1, 8) == "\137PNG\r\n\26\n" then return "png" end
	if body:sub(1, 3) == "\255\216\255" then return "jpg" end
end

-- GMod dokuyu 2'nin kuvvetine büyüttüğü için mat:Width() gerçek oranı vermiyor;
-- gerçek boyut PNG IHDR / JPEG SOF başlığından okunur.
SardonMatbaa.ImageSize = SardonMatbaa.ImageSize or setmetatable({}, { __mode = "k" })

local function be16(s, i)
	local a, b = s:byte(i, i + 1)
	return (a or 0) * 256 + (b or 0)
end

local function readSize(body)
	if !body then return end

	if body:sub(1, 8) == "\137PNG\r\n\26\n" then
		return be16(body, 17) * 65536 + be16(body, 19), be16(body, 21) * 65536 + be16(body, 23)
	end

	if body:sub(1, 2) == "\255\216" then
		local i, n = 3, #body

		while i + 8 <= n do
			if body:byte(i) != 0xFF then return end

			local marker = body:byte(i + 1)

			if marker >= 0xC0 and marker <= 0xCF and marker != 0xC4 and marker != 0xC8 and marker != 0xCC then
				return be16(body, i + 7), be16(body, i + 5)
			end

			i = i + 2 + be16(body, i + 2)
		end
	end
end

local function openMaterial(path)
	local mat = Material("../data/" .. path, "smooth mips")

	if mat and !mat:IsError() then
		local w, h = readSize(file.Read(path, "DATA"))

		if w and h and w > 0 and h > 0 then
			SardonMatbaa.ImageSize[mat] = { w, h }
		end

		return mat
	end
end

local function fetch(entry, url, sources, i)
	local src = sources[i]

	if !src then
		entry.state = "fail"
		return
	end

	http.Fetch(src, function(body, size, headers, code)
		local ext = code == 200 and #body <= MAX_BYTES and sniff(body)

		if !ext then
			fetch(entry, url, sources, i + 1)
			return
		end

		local path = DIR .. "/" .. util.CRC(url) .. "." .. ext
		file.Write(path, body)

		entry.mat = openMaterial(path)
		entry.state = entry.mat and "ok" or "fail"
	end, function()
		fetch(entry, url, sources, i + 1)
	end)
end

-- Görsel hazırsa Material'i döndürür; değilse nil + durum ("loading" / "fail")
function SardonMatbaa.GetMaterial(url)
	if !isstring(url) or url == "" then return nil, "fail" end

	local entry = cache[url]

	if entry then return entry.mat, entry.state end

	entry = { state = "loading" }
	cache[url] = entry

	local base = DIR .. "/" .. util.CRC(url)

	for _, ext in ipairs({ "png", "jpg" }) do
		if file.Exists(base .. "." .. ext, "DATA") then
			entry.mat = openMaterial(base .. "." .. ext)

			if entry.mat then
				entry.state = "ok"
				return entry.mat, "ok"
			end
		end
	end

	fetch(entry, url, { url, "https://proxy.duckduckgo.com/iu/?u=" .. urlEncode(url) }, 1)

	return nil, "loading"
end

-- Polaroid masası/projektörü gibi eski XeninUI:DownloadIcon kullanan entity'ler için:
-- ent[var] alanını hazırsa Material'e, değilse "Loading"e ayarlar.
function SardonMatbaa.ApplyIcon(ent, url, var)
	local mat, state = SardonMatbaa.GetMaterial(url)

	ent[var or "Icon"] = mat or (state == "loading" and "Loading" or nil)
end

-- Görseli oranını bozmadan verilen kutuya ortalayarak sığdırır
function SardonMatbaa.DrawFit(mat, x, y, w, h, col)
	local size = SardonMatbaa.ImageSize[mat]
	local iw, ih = size and size[1] or mat:Width(), size and size[2] or mat:Height()

	if iw <= 0 or ih <= 0 then iw, ih = w, h end

	local s = math.min(w / iw, h / ih)
	local dw, dh = iw * s, ih * s

	surface.SetMaterial(mat)
	surface.SetDrawColor(col or color_white)
	surface.DrawTexturedRect(x + (w - dw) / 2, y + (h - dh) / 2, dw, dh)
end
