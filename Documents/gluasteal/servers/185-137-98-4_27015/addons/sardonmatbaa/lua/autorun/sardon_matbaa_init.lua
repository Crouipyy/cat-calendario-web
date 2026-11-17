-- "addons\\sardonmatbaa\\lua\\autorun\\sardon_matbaa_init.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- [#sardon] addon-utils/sh_sardon_utils.lua'daki SardonUtil:LoadAddon loader'ı ile aynı
-- desen (bkz. [sardon] zonko): SardonUtil hazır değilse SardonUtilReady'yi bekle.
if not SardonUtil then
	hook.Add("SardonUtilReady", "sardon_matbaa", function()
		SardonUtil:LoadAddon("sardon_matbaa", false)
	end)
else
	SardonUtil:LoadAddon("sardon_matbaa", false)
end
