-- "addons\\sardonbakanlik\\lua\\sardon_bakanlik\\cl_2_emir.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Expediente :: Órdenes. SE BUSCA ilanları, arama ve tutuklama emirleri, hapis onayları.

local B = SardonBakanlik
local U = B.UI
local R = U.R

local TUR_RENK = {aranan = R.kizil, tutuklama = R.kizil, arama = R.altinAcik, hapis = R.mor}

local function Iste() B.Sor("emir.liste", {}) end

-- Nueva orden kipi. on: {hedef, ad} (Expediente sayfasından gelince dolu)
local function NuevoEmir(on)
     local ply = LocalPlayer()
     local tur = "tutuklama"
     local hedef, hedefAd = on and on.hedef, on and on.ad
     local TURLER = {{id = "aranan", ad = "Se busca", izin = "aranan"}, {id = "tutuklama", ad = "Tutuklama"}, {id = "arama", ad = "Arama (ev)"}}
     if B.Yetkili(ply, "aranan") then tur = "aranan" end

     B.Kip({baslik = "Nueva orden", w = 620, ciz = function(x, y, w)
          local bw = (w - 2 * 8) / 3
          for i, t in ipairs(TURLER) do
               local bx = x + (i - 1) * (bw + 8)
               local kapali = t.izin and not B.Yetkili(ply, t.izin)
               local sec = tur == t.id
               local ustunde = not kapali and U.Icinde(bx, y, bw, 38)
               U.Kutu(bx, y, bw, 38, R.altin, sec and 0.24 or (ustunde and 0.1 or 0.03))
               U.Cerceve(bx, y, bw, 38, kapali and R.kapali or (sec and R.altinAcik or R.cizgi), 0.85)
               U.Yazi(B.Buyuk(t.ad), 11, 600, bx + bw / 2, y + 19, kapali and R.kapali or (sec and R.fildisiAcik or R.ada), 1, 1.4)
               if ustunde then
                    U.imlec = true
                    if U.Tik(bx, y, bw, 38) then tur = t.id end
               elseif kapali and U.Icinde(bx, y, bw, 38) then
                    U.ipucu = "Los avisos SE BUSCA los emiten categoría 3 o superior."
               end
          end

          local cy = y + 56
          local hazir = true
          if tur == "arama" then
               U.Etiket("Número de vivienda", x, cy + 6, R.soluk, 0, 10)
               local ev = U.Girdi("kip.ev", x, cy + 18, 160, 36, "p. ej. 7", {sayi = true, maks = 3})
               U.Paragraf("Al aprobarse " .. B.SureUzun(B.Ayar.AramaEmriSure) .. " tendrá validez; el Alohomora del agente de servicio abre esa puerta.", 12, 700, x + 180, cy + 16, w - 180, R.ada, 18)
               hazir = tonumber(ev) ~= nil
               cy = cy + 68
          else
               U.Etiket("Persona", x, cy + 6, R.soluk, 0, 10)
               U.Kutu(x, cy + 18, w - 130, 36, R.zeminKoyu, 0.7)
               U.Cerceve(x, cy + 18, w - 130, 36, R.cizgi, 0.75)
               U.Yazi(hedefAd or "Sin seleccionar", 14, 600, x + 12, cy + 36, hedefAd and R.fildisi or R.soluk)
               if U.Dugme(x + w - 120, cy + 18, 120, 36, "Elegir", "ikincil") then
                    B.KisiSec("Objetivo de la orden", function(id, ad) hedef, hedefAd = id, ad end)
               end
               hazir = hedef ~= nil
               cy = cy + 68

               if tur == "aranan" then
                    U.Etiket("Recompensa (del Tesoro)", x, cy + 6, R.soluk, 0, 10)
                    U.Girdi("kip.odul", x, cy + 18, 160, 36, "0", {sayi = true, maks = 5})
                    U.Yazi("Como máximo " .. B.Para(B.Ayar.OdulAzami) .. "; se paga a quien capture y encarcele.", 12, 700, x + 180, cy + 36, R.ada)
                    cy = cy + 68
               end
          end

          U.Etiket("Motivo", x, cy + 6, R.soluk, 0, 10)
          local gerekce = U.Girdi("kip.gerekce", x, cy + 18, w, 90, "Emir neden isteniyor?", {cokSatir = true, maks = 400})
          cy = cy + 122
          hazir = hazir and #string.Trim(gerekce) >= 5

          local kendi = B.Yetkili(ply, "emir_onay")
          U.Yazi(kendi and "Como categoría 4, la orden entra en vigor sin aprobación." or "La solicitud pasa a aprobación de un superior.", 12, 700, x, cy + 20, R.soluk)
          if U.Dugme(x + w - 180, cy, 180, 38, kendi and "Sellar" or "Enviar a aprobación", "ana", not hazir) then
               B.Iste("emir.iste", {tur = tur, hedef = hedef, ev = tonumber(U.GirdiDeger("kip.ev")), odul = tonumber(U.GirdiDeger("kip.odul")), gerekce = gerekce})
               if kendi then U.MuhurBas(x + w - 90, cy - 30) end
               B.KipKapat()
          end
          return cy + 38 - y
     end})
end

local function EmirKarti(x, y, w, e, v)
     local ply = LocalPlayer()
     local renk = TUR_RENK[e.tur] or R.ada
     local h = 96
     U.Kart(x, y, w, h, e.durum == "etkin" and (e.tur == "aranan" or e.tur == "tutuklama"))
     U.Kutu(x, y, 3, h, renk, 0.9)

     U.Rozet(B.EmirTurAd[e.tur] or e.tur, x + 18, y + 22, renk, e.durum == "etkin")
     U.Yazi(U.Kisalt(e.hedef_ad, 17, 600, w - 330), 17, 600, x + 18, y + 50, R.fildisiAcik)
     U.Yazi(U.Kisalt(e.gerekce, 12, 700, w - 40), 12, 700, x + 18, y + 76, R.govde)

     local sag = x + w - 18
     if e.tur == "aranan" and e.odul > 0 then
          U.Yazi(B.Para(e.odul), 17, 600, sag, y + 22, R.altinAcik, 2)
          U.Etiket("Recompensa", sag - U.Olc(B.Para(e.odul), 17, 600) - 10, y + 22, R.soluk, 2, 9)
     elseif e.bitis > 0 and e.durum == "etkin" then
          U.Yazi(B.Sure(math.max(0, e.bitis - os.time())) .. " restante", 13, 600, sag, y + 22, R.altinAcik, 2)
     elseif e.cevrimici then
          U.Rozet("En línea", sag, y + 22, R.yesil, false, 2)
     end

     local kim = e.durum == "bekliyor" and ("Solicitante: " .. e.isteyen_ad) or ("Aprobación: " .. e.onaylayan_ad)
     U.Yazi(kim .. " · " .. B.Once(e.zaman), 11, 700, sag, y + 50, R.soluk, 2)

     -- eylemler: satırın üstündeyken
     if U.Icinde(x, y, w, h) then
          local bx = sag
          if e.durum == "bekliyor" and B.Yetkili(ply, "emir_onay") then
               bx = bx - 110
               if U.Dugme(bx, y + 60, 110, 28, "Sellar", "ana") then
                    B.Iste("emir.karar", {id = e.id, onay = true})
                    U.MuhurBas(x + w - 120, y + 30)
               end
               bx = bx - 96
               if U.Dugme(bx, y + 60, 90, 28, "Rechazar", "tehlike") then B.Iste("emir.karar", {id = e.id, onay = false}) end
          elseif (e.durum == "etkin" or e.durum == "bekliyor") and (e.isteyen == v.ben or B.Yetkili(ply, "emir_onay")) then
               bx = bx - 110
               if U.Dugme(bx, y + 60, 110, 28, "Retirar", "tehlike") then B.Iste("emir.kaldir", {id = e.id}) end
          end
          if e.hedef > 0 then
               bx = bx - 82
               if U.Dugme(bx, y + 60, 76, 28, "Expediente", "duz") then B.Git("sicil", {kisi = e.hedef}) end
          end
          if e.dosya > 0 and B.Yetkili(ply, "dosya") then
               bx = bx - 108
               if U.Dugme(bx, y + 60, 102, 28, "Archivo #" .. e.dosya, "duz") then B.Git("dosya", {id = e.dosya}) end
          end
     end
     return h
end

local function Ciz(x, y, w, h)
     local ply = LocalPlayer()
     if U.Dugme(x + w - 200, y + 2, 200, 34, "Nueva orden", "ana", not B.Yetkili(ply, "emir_iste"), B.YetkiIpucu("emir_iste")) then NuevoEmir() end

     local v = B.Veri["emir.liste"]
     if not v then return U.Bekleniyor(x, y, w, h) end

     local solW = (w - 28) / 2
     local sagX = x + solW + 28

     -- sol: yürürlükte
     U.Bolum("En vigor", x, y + 20, solW - 220, #v.etkin .. " emir")
     local ly, lh = y + 48, h - 48
     if #v.etkin == 0 then
          U.Bos(x, ly, solW, lh, "En vigor emir yok")
     else
          local kay = U.Kaydir("emir.etkin", x, ly, solW, lh, #v.etkin * 106)
          for i, e in ipairs(v.etkin) do
               local sy = ly + (i - 1) * 106 - kay
               if U.Gorunur(sy, 106) then EmirKarti(x, sy, solW - 12, e, v) end
          end
          U.KaydirBitir()
     end

     -- sağ: bekleyen + geçmiş
     U.Bolum("Pendientes de aprobación", sagX, y + 20 + 34, solW, #v.bekleyen > 0 and (#v.bekleyen .. " istek") or nil)
     local by = y + 48 + 34
     local bekH = math.min(#v.bekleyen, 3) * 106
     if #v.bekleyen == 0 then
          U.Yazi("No hay solicitudes pendientes.", 13, 700, sagX, by + 14, R.soluk)
          bekH = 40
     else
          local kay = U.Kaydir("emir.bekleyen", sagX, by, solW, bekH, #v.bekleyen * 106)
          for i, e in ipairs(v.bekleyen) do
               local sy = by + (i - 1) * 106 - kay
               if U.Gorunur(sy, 106) then EmirKarti(sagX, sy, solW - 12, e, v) end
          end
          U.KaydirBitir()
     end

     local gy = by + bekH + 22
     U.Bolum("Historial", sagX, gy, solW)
     gy = gy + 18
     local gh = y + h - gy
     local kay = U.Kaydir("emir.gecmis", sagX, gy, solW, gh, #v.gecmis * 38)
     for i, e in ipairs(v.gecmis) do
          local sy = gy + (i - 1) * 38 - kay
          if U.Gorunur(sy, 38) then
               U.Kutu(sagX, sy + 37, solW - 12, 1, R.cizgi, 0.22)
               U.Yazi(B.Buyuk(B.EmirTurAd[e.tur] or e.tur), 9, 600, sagX + 4, sy + 19, R.soluk, 0, 1.2)
               U.Yazi(U.Kisalt(e.hedef_ad, 13, 600, solW - 330), 13, 600, sagX + 130, sy + 19, R.ada)
               U.Yazi(e.durum == "red" and "Rechazado" or "Cerrado", 11, 700, sagX + solW - 130, sy + 19, e.durum == "red" and R.kizil or R.soluk, 2)
               U.Yazi(B.Once(e.bitis > 0 and e.bitis or e.zaman), 11, 700, sagX + solW - 20, sy + 19, R.soluk, 2)
          end
     end
     U.KaydirBitir()
end

B.Sayfa("emir", {
     ad = "Órdenes", sira = 5, izin = "emir", rozet = "onay", kanallar = {["emir.liste"] = true},
     alt = "Avisos de búsqueda, órdenes de registro y detención, aprobaciones de prisión.",
     ac = function(arg)
          Iste()
          if arg.yeni then NuevoEmir(arg.yeni) end
     end,
     ciz = Ciz,
})
