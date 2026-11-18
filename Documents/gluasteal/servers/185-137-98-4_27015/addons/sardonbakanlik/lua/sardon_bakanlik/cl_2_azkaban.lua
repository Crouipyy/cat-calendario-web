-- "addons\\sardonbakanlik\\lua\\sardon_bakanlik\\cl_2_azkaban.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Expediente :: Azkaban. Detenidolar, kalan süreler, tahliye ve af.

local B = SardonBakanlik
local U = B.UI
local R = U.R

local alinma = 0 -- verinin geldiği an (kalan süreyi istemcide akıtmak için)

local function Ciz(x, y, w, h)
     local v = B.Veri["azkaban.liste"]
     if not v then return U.Bekleniyor(x, y, w, h) end
     local ply = LocalPlayer()

     -- üst şerit
     U.Kart(x, y + 6, w, 92)
     U.Yazi(#v.liste, 36, 600, x + 28, y + 46, R.fildisiAcik)
     U.Etiket("Detenido", x + 28, y + 80, R.ust, 0, 10)
     U.Yazi(v.hucre, 36, 600, x + 190, y + 46, v.hazir and R.fildisiAcik or R.kizil)
     U.Etiket("Punto de celda", x + 190, y + 80, R.ust, 0, 10)
     U.Paragraf(v.hazir and ("El tiempo solo corre con el detenido conectado. Prisión directa como máximo " .. B.SureUzun(B.Ayar.DogrudanHapis) .. ", con aprobación o sentencia como máximo " ..
          B.SureUzun(B.Ayar.AzamiHapis) .. ". Quien cumpla la pena queda liberado automáticamente.")
          or "Las celdas de Azkaban no están definidas: no se puede enviar a nadie. Un superadmin debe configurarlas en Shine Admin › Ministerio o con /AzkabanNokta.",
          13, 700, x + 400, y + 26, w - 430, v.hazir and R.ada or R.kizil, 20)

     local ly, lh = y + 122, h - 122
     if #v.liste == 0 then return U.Bos(x, ly, w, lh, "Las celdas están vacías", "Los detenidos aparecen aquí al aplicar sanción desde un expediente o por sentencia del Wizengamot.") end

     local gecen = RealTime() - alinma
     local kay = U.Kaydir("azkaban.liste", x, ly, w, lh, #v.liste * 88)
     for i, t in ipairs(v.liste) do
          local sy = ly + (i - 1) * 88 - kay
          if U.Gorunur(sy, 88) then
               local kalan = t.cevrimici and math.max(0, t.kalan - gecen) or t.kalan
               U.Kutu(x, sy, w - 12, 80, R.panel, 0.7)
               U.Cerceve(x, sy, w - 12, 80, R.cizgi, 0.45)
               U.Kutu(x, sy, 3, 80, R.mor, 0.9)

               U.Baklava(x + 24, sy + 26, 5, t.cevrimici and R.yesil or R.pirinc, 1)
               U.Yazi(U.Kisalt(t.ad, 17, 600, 320), 17, 600, x + 42, sy + 26, R.fildisiAcik)
               U.Yazi(U.Kisalt(t.suc, 12, 700, 520), 12, 700, x + 42, sy + 52, R.govde)
               U.Yazi("Veren: " .. t.veren_ad .. " · " .. B.Once(t.zaman) .. " · celda " .. t.hucre, 11, 700, x + 42, sy + 68, R.soluk)

               local bx = x + 640
               U.Yazi(B.Sure(kalan), 22, 600, bx, sy + 28, t.cevrimici and R.fildisiAcik or R.soluk)
               U.Etiket(t.cevrimici and "Restante" or "Restante (desconectado, tiempo detenido)", bx + 96, sy + 30, R.soluk, 0, 9)
               U.Cubuk(bx, sy + 54, 300, 5, t.toplam > 0 and (1 - kalan / t.toplam) or 0, R.mor)

               local sag = x + w - 30
               if B.Yetkili(ply, "af") then
                    sag = sag - 90
                    if U.Dugme(sag, sy + 24, 90, 32, "Af", "ikincil", false, "Indulto del Ministerio: queda en el expediente como amnistía.") then
                         B.Onay("Indulto del Ministerio", t.ad .. " será indultado y liberado.", "Indultar", function() B.Iste("azkaban.tahliye", {id = t.id, af = true}) end)
                    end
                    sag = sag - 8
               end
               if B.Yetkili(ply, "tahliye") then
                    sag = sag - 110
                    if U.Dugme(sag, sy + 24, 110, 32, "Liberar", "tehlike") then
                         B.Onay("Liberar", t.ad .. " será liberado antes de cumplir la pena.", "Liberar", function() B.Iste("azkaban.tahliye", {id = t.id}) end, true)
                    end
                    sag = sag - 8
               end
               sag = sag - 80
               if U.Dugme(sag, sy + 24, 80, 32, "Expediente", "duz") then B.Git("sicil", {kisi = t.id}) end
          end
     end
     U.KaydirBitir()
end

B.Sayfa("azkaban", {
     ad = "Azkaban", sira = 6, izin = "olay", rozet = "tutuklu", kanallar = {["azkaban.liste"] = true},
     alt = "La fortaleza del Mar del Norte: quién, por qué y cuánto.",
     ac = function() B.Sor("azkaban.liste", {}) end,
     veri = function(anahtar) if anahtar == "azkaban.liste" then alinma = RealTime() end end,
     ciz = Ciz,
})
