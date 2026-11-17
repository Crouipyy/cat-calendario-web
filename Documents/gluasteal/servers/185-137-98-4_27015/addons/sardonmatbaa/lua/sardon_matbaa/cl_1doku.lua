-- "addons\\sardonmatbaa\\lua\\sardon_matbaa\\cl_1doku.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Matbaa arayüz dokuları (matbaa-ui paketi). Önce materials/matbaa/ui yolunu dener
-- (Workshop ile gelmişse); yoksa cl_0doku_*.lua içindeki gömülü PNG'yi
-- data/sardon_matbaa/ui/ altına yazıp "../data/..." yolundan yükler.
-- Material nesneleri bir kez oluşturulup saklanır.
SardonMatbaa = SardonMatbaa or {}

local G = SardonMatbaa
local cache = {}

local function paketYolu(ad)
	local ikon = ad:match("^icon%-(.+)$")

	return ikon and ("matbaa/ui/icons-white/" .. ikon .. ".png") or ("matbaa/ui/" .. ad .. ".png")
end

function G.UIDoku(ad)
	local mat = cache[ad]
	if mat != nil then return mat or nil end

	mat = Material(paketYolu(ad), "smooth noclamp")

	if mat:IsError() then
		local veri = G.DokuVeri and G.DokuVeri[ad]
		mat = false

		if veri then
			local yol = "sardon_matbaa/ui/" .. ad .. "_" .. (G.DokuSurum[ad] or "0") .. ".png"

			if !file.Exists(yol, "DATA") then
				file.CreateDir("sardon_matbaa/ui")
				local ikili = util.Base64Decode(veri)
				if ikili then file.Write(yol, ikili) end
			end

			local m = Material("../data/" .. yol, "smooth noclamp")
			if !m:IsError() then mat = m end
		end
	end

	cache[ad] = mat
	return mat or nil
end

-- Dokuyu verilen kutuya çizer; doku yoksa false döner (çağıran yedek çizim yapar)
function G.UIDokuCiz(ad, x, y, w, h, renk)
	local mat = G.UIDoku(ad)
	if !mat then return false end

	surface.SetMaterial(mat)
	surface.SetDrawColor(renk or color_white)
	surface.DrawTexturedRect(x, y, w, h)
	return true
end
