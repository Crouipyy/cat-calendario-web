-- "addons\\sardongolge\\lua\\sardon_golge\\_sh_3gorev.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Gölge :: ortak — Görev Atölyesi şeması: diyalog görevinin golge_* koşulları editörde seçilebilsin
-- (asıl işlevler sv_3golge.lua'da SardonGorev.Kosul'a yazılır). [sardon] gorev bu eklentiden sonra yüklenir.
local S = SardonGolge

local function SemaKaydet()
     local G = SardonGorev
     if not (G and G.Sema and G.Sema.Kosul and G.SemaSira and G.SemaSira.Kosul) then return false end

     local function K(id, t)
          t.id = id
          t.alanlar = t.alanlar or {}
          t.alanlar[#t.alanlar + 1] = { k = "tersi", ad = "Tersi (değilse)", tip = "bool", v = false }
          G.Sema.Kosul[id] = t
          if not table.HasValue(G.SemaSira.Kosul, id) then table.insert(G.SemaSira.Kosul, id) end
     end

     K("golge_tanis", { ad = "Gölge: daha önce tanıştı", ozet = function() return "Gölge ile tanışmış" end })
     K("golge_grup", { ad = "Gölge: diyalog grubu", alanlar = {
          { k = "deger", ad = "Grup", tip = "secim", v = "snatcher", secenekler = {
               { id = "snatcher", ad = "Snatcher" }, { id = "ogrenci", ad = "Öğrenci" }, { id = "profesor", ad = "Profesör / Hogwarts çalışanı" },
               { id = "bakanlik", ad = "Bakanlık / Seherbaz" }, { id = "karanlik", ad = "Karanlık Büyücü" }, { id = "diger", ad = "Diğer" } } },
     }, ozet = function(e) return "Gölge grubu: " .. tostring(e.deger or "?") end })
     K("golge_alabilir", { ad = "Gölge: bu hafta alabilir (hak + para)", ozet = function() return "Gölge'den alabilir" end })
     K("golge_bakanlik_yakala", { ad = "Gölge: Bakanlık yalanını yakalar (%50)", ozet = function() return "Bakanlık yalanı yakalandı" end })
     K("golge_mal_var", { ad = "Gölge: tezgâhta ona göre mal var", ozet = function() return "Gölge'nin malı var" end })
     return true
end

if not SemaKaydet() then
     timer.Create("SardonGolge.Sema", 1, 60, function()
          if SemaKaydet() then timer.Remove("SardonGolge.Sema") end
     end)
end
