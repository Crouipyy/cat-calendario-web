-- "addons\\sardonyaratik\\lua\\autorun\\sh_sardon_yaratik.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- [sardon] yaratik :: Sihirli Yaratıklar (yanında gezdirme, omuz, vivaryum bakımı, yaşam döngüsü, gen).
-- Dosyalar lua/sardon_yaratik/ altında; SardonUtil önekle (sv_/sh_/cl_) yükler, alfabetik sırayla
-- (_sh_ dosyaları önce). Varlık: lua/entities/sardon_yaratik.lua.
if not SardonUtil then
     hook.Add("SardonUtilReady", "sardon_yaratik", function()
          SardonUtil:LoadAddon("sardon_yaratik", false)
     end)
else
     SardonUtil:LoadAddon("sardon_yaratik", false)
end
