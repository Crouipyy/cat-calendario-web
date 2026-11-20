-- "addons\\sardonkitap\\lua\\sardon_kitap\\_sh_3runler.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Kitap :: kitapta öğretilen ama [sardon] akran'da elle çizilmiş rünü olmayan büyüler.
-- Rünler Akran'ın SA.Runler tablosuna eklenir (aynı büyü her yerde aynı rünle çizilsin);
-- tanıma da Akran'ın tanıyıcısıyla yapılır (SA.Benzerlik, eşik SA.Ayar.esik).
-- Şablon: [-1, 1] karesinde tek vuruş, y yukarı.

local SK = SardonKitap

local function Param(n, fn)
     local out = {}
     for i = 0, n do
          local x, y = fn(i / n)
          out[#out + 1] = {x = x, y = y}
     end
     return out
end

local function Cizgi(...)
     local out = {}
     for _, p in ipairs({...}) do out[#out + 1] = {x = p[1], y = p[2]} end
     return out
end

SK.EK_RUNLER = {
     ["Lux Bulbus"] = {
          tarif = "Işığı içten dışa yay: ortadan başla, saat yönünün tersine genişleyen bir buçuk tur sarmal çiz.",
          yap = function()
               return Param(54, function(t)
                    local a = t * math.pi * 3
                    local r = 0.12 + 0.78 * t
                    return math.cos(a) * r, math.sin(a) * r
               end)
          end
     },
     ["Spongify"] = {
          tarif = "Sekip giden bir top gibi: soldan sağa üç sıçrama çiz, her sıçrama bir öncekinden alçak olsun.",
          yap = function()
               return Param(60, function(t)
                    return -0.95 + 1.9 * t, -0.6 + 1.3 * (1 - t * 0.7) * math.abs(math.sin(3 * math.pi * t))
               end)
          end
     },
     ["Lumos"] = {
          tarif = "Işığı asanın ucuna taşı: aşağıdan dümdüz yukarı çık, tepede saat yönünde küçük bir daire çizerek bitir.",
          yap = function()
               local out = Cizgi({0, -0.9}, {0, 0.25})
               for i = 1, 24 do
                    local a = math.rad(-90 - i * 15)
                    out[#out + 1] = {x = math.cos(a) * 0.3, y = 0.55 + math.sin(a) * 0.3}
               end
               return out
          end
     },
     ["Petrificus Totalus"] = {
          tarif = "Bedeni bağla: sol üstten başla, sağa, aşağı, sola ve tekrar yukarı çıkarak kapalı bir dikdörtgen çiz.",
          yap = function()
               return Cizgi({-0.45, 0.9}, {0.45, 0.9}, {0.45, -0.9}, {-0.45, -0.9}, {-0.45, 0.85})
          end
     },
     ["Expelliarmus"] = {
          tarif = "Şimşek gibi: sol üstten sağ aşağıya doğru keskin bir zikzak çiz, son çizgiyi en uzun tut.",
          yap = function()
               return Cizgi({-0.8, 0.85}, {0.15, 0.2}, {-0.3, 0.0}, {0.85, -0.85})
          end
     },
     ["Book a mons"] = {
          tarif = "Açık bir kitap çiz: sol alttan yukarı çık, sırta in, sırttan tekrar yukarı çık ve sağ sayfayı aşağı indir.",
          yap = function()
               return Cizgi({-0.9, -0.6}, {-0.9, 0.45}, {0, 0.25}, {0, -0.7}, {0, 0.25}, {0.9, 0.45}, {0.9, -0.6})
          end
     },
}

-- ağaçtaki ad ile Akran'daki ad farklı olanlar
SK.RUN_ESLER = {["Avis"] = "Avis Sard"}

function SK.RunleriKur()
     local SA = SardonAkran
     if not SA or not SA.Runler or not SA.Sablon then return false end

     local onbellek
     for i = 1, 8 do
          local ad, deger = debug.getupvalue(SA.Sablon, i)
          if ad == nil then break end
          if ad == "onbellek" and istable(deger) then onbellek = deger break end
     end

     for buyu, tanim in pairs(SK.EK_RUNLER) do
          if SA.Runler[buyu] == nil or SA.Runler[buyu].sardonKitap then
               tanim.sardonKitap = true
               SA.Runler[buyu] = tanim
               if onbellek then onbellek[buyu] = nil end
          end
     end
     for ad, es in pairs(SK.RUN_ESLER) do
          if SA.Runler[ad] == nil and SA.Runler[es] then
               SA.Runler[ad] = SA.Runler[es]
               if onbellek then onbellek[ad] = nil end
          end
     end
     return true
end

if not SK.RunleriKur() then
     hook.Add("InitPostEntity", "SardonKitap.Runler", function() SK.RunleriKur() end)
     timer.Simple(5, function() SK.RunleriKur() end)
end

-- rün tanıma: Akran yoksa kitap büyüsü çizilemez (sunucu reddeder, istemci uyarır)
function SK.RunVar()
     return SardonAkran ~= nil and SardonAkran.Benzerlik ~= nil and SardonAkran.Sablon ~= nil
end

function SK.RunEsik()
     local SA = SardonAkran
     return ((SA and SA.Ayar and tonumber(SA.Ayar.esik)) or 72) / 100
end
