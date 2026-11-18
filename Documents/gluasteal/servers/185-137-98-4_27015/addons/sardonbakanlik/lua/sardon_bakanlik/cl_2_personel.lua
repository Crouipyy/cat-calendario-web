-- "addons\\sardonbakanlik\\lua\\sardon_bakanlik\\cl_2_personel.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sicil Defteri :: Personel. Teşkilat ve kadro, atama / terfi (Karma), hizmet sicili, ekipler.

local B = SardonBakanlik
local U = B.UI
local R = U.R

local D = {sekme = "kadro", daire = nil, secili = nil}

local function KisiSecildi(id)
     D.secili = id
     B.Veri["personel.kisi"] = nil
     U.KaydirSifirla("personel.sicil")
     B.Sor("personel.kisi", {id = id})
end

local function KademeCiz(x, y, kademe, renk)
     for i = 1, 5 do
          if i <= kademe then U.Baklava(x + (i - 1) * 13, y, 4, renk or R.altinAcik, 1) else U.BaklavaCizgi(x + (i - 1) * 13, y, 4, R.pirinc, 0.6) end
     end
end

local function Bul(v, id)
     for _, k in ipairs(v.liste) do
          if k.id == id then return k end
     end
end

local function EkipAd(v, id)
     for _, e in ipairs(v.ekipler) do
          if e.id == id then return e.ad end
     end
end

----------------------------------------------------------------------------------------
-- Atama kipi
----------------------------------------------------------------------------------------
local function AtamaKipi(k, siniflar)
     local secili = k.sinif
     local daire = k.daire
     local ben = B.Bilgi(LocalPlayer())

     B.Kip({baslik = "Nombramiento · " .. k.ad, w = 640, ciz = function(x, y, w)
          U.Yazi("Elegir plaza cambia de verdad la clase Helix y su whitelist; la acción queda en el expediente de servicio y en el registro de auditoría.", 11, 700, x, y + 6, R.soluk)

          local ly, lh = y + 26, 250
          local kay = U.Kaydir("kip.sinif", x, ly, w, lh, #siniflar * 44)
          for i, s in ipairs(siniflar) do
               local sy = ly + (i - 1) * 44 - kay
               if U.Gorunur(sy, 44) then
                    local sec = secili == s.id
                    local tik = (not s.dolu or s.id == k.sinif) and U.Satir(x, sy, w - 10, 44, sec)
                    U.Yazi(U.Kisalt(s.ad, 14, 600, 300), 14, 600, x + 14, sy + 22, s.dolu and s.id ~= k.sinif and R.kapali or R.fildisi)
                    U.Yazi(s.daire ~= "" and B.DaireAd(s.daire, true) or "DEPARTAMENTO POR ASIGNAR", 10, 600, x + 340, sy + 22, R.soluk, 0, 1.2)
                    KademeCiz(x + w - 110, sy + 22, s.kademe)
                    if s.id == k.sinif then U.Etiket("Actual", x + 470, sy + 22, R.ust, 0, 9)
                    elseif s.dolu then U.Etiket("Plaza cubierta", x + 470, sy + 22, R.kizil, 0, 9) end
                    if tik then secili = s.id end
               end
          end
          U.KaydirBitir()

          local cy = ly + lh + 14
          local serbest = false
          for _, s in ipairs(siniflar) do
               if s.id == secili and s.serbest then serbest = true end
          end

          if serbest then
               U.Etiket("Departamento", x, cy + 6, R.soluk, 0, 10)
               local dx = x
               cy = cy + 18
               for _, d in ipairs(B.Daireler) do
                    local izinli = ben.kademe >= 5 or ben.denetci or ben.daire == "makam" or ben.daire == d.id
                    local dw = U.Olc(d.kisa, 10, 600, 1.2) + 22
                    if dx + dw > x + w then dx, cy = x, cy + 32 end
                    local sec = daire == d.id
                    local ustunde = izinli and U.Icinde(dx, cy, dw, 26)
                    U.Kutu(dx, cy, dw, 26, R.altin, sec and 0.24 or (ustunde and 0.1 or 0.02))
                    U.Cerceve(dx, cy, dw, 26, izinli and (sec and R.altinAcik or R.cizgi) or R.kapali, 0.8)
                    U.Yazi(d.kisa, 10, 600, dx + dw / 2, cy + 13, izinli and (sec and R.fildisiAcik or R.ada) or R.kapali, 1, 1.2)
                    if ustunde then
                         U.imlec = true
                         U.ipucu = d.ad
                         if U.Tik(dx, cy, dw, 26) then daire = d.id end
                    end
                    dx = dx + dw + 6
               end
               cy = cy + 38
               U.Girdi("kip.unvan", x, cy, w / 2 - 6, 34, "Cargo (p. ej. Obliviator)", {maks = 40, deger = k.serbest and k.unvan or ""})
               U.Girdi("kip.birim", x + w / 2 + 6, cy, w / 2 - 6, 34, "Unidad (opcional)", {maks = 40, deger = k.serbest and k.birim or ""})
               cy = cy + 46
          end

          cy = cy + 6
          if U.Dugme(x + w - 170, cy, 170, 38, "Sellar nombramiento", "ana") then
               B.Iste("personel.ata", {id = k.id, sinif = secili, daire = serbest and (daire or "") or nil,
                    unvan = serbest and U.GirdiDeger("kip.unvan") or nil, birim = serbest and U.GirdiDeger("kip.birim") or nil})
               U.MuhurBas(x + w - 85, cy - 30)
               B.KipKapat()
          end
          if U.Dugme(x + w - 310, cy, 130, 38, "Cancelar", "ikincil") then B.KipKapat() end
          return cy + 38 - y
     end})
end

----------------------------------------------------------------------------------------
-- Kadro
----------------------------------------------------------------------------------------
local function DaireListesi(x, y, w, h, v)
     local sayilar, mesaide = {}, {}
     for _, k in ipairs(v.liste) do
          local d = k.daire ~= "" and k.daire or "yok"
          sayilar[d] = (sayilar[d] or 0) + 1
          if k.gorev then mesaide[d] = (mesaide[d] or 0) + 1 end
     end

     local function Satir(sy, id, ad, n, m, alt)
          local sec = D.daire == id
          local tik = U.Satir(x, sy, w, 52, sec)
          U.Yazi(U.Kisalt(ad, 13, 600, w - 70), 13, 600, x + 14, sy + 18, sec and R.fildisiAcik or R.fildisi)
          U.Yazi(alt, 10, 700, x + 14, sy + 37, R.soluk)
          U.Yazi(n, 15, 600, x + w - 14, sy + 18, R.altinAcik, 2)
          if m > 0 then U.Yazi(m .. " de servicio", 10, 700, x + w - 14, sy + 37, R.yesil, 2) end
          if tik then
               D.daire = id
               U.KaydirSifirla("personel.liste")
          end
     end

     local toplamMesai = 0
     for _, n in pairs(mesaide) do toplamMesai = toplamMesai + n end
     Satir(y, nil, "Todo el personal", #v.liste, toplamMesai, "Ministerio y Oficina de Aurores")
     local sy = y + 56
     for _, d in ipairs(B.Daireler) do
          Satir(sy, d.id, d.ad, sayilar[d.id] or 0, mesaide[d.id] or 0, d.kat .. ". planta")
          sy = sy + 54
     end
     if (sayilar.yok or 0) > 0 then Satir(sy, "yok", "Sin departamento", sayilar.yok, mesaide.yok or 0, "Pendiente de asignación") end
end

local function KadroListesi(x, y, w, h, v)
     local liste = {}
     for _, k in ipairs(v.liste) do
          if D.daire == nil or k.daire == D.daire or (D.daire == "yok" and k.daire == "") then liste[#liste + 1] = k end
     end
     table.sort(liste, function(a, b)
          if a.sira ~= b.sira then return a.sira > b.sira end
          return a.ad < b.ad
     end)

     if #liste == 0 then return U.Bos(x, y, w, h, "No hay personal en este departamento", "La admisión a la facción la deciden los responsables; la asignación de departamento se hace aquí.") end

     local kay = U.Kaydir("personel.liste", x, y, w, h, #liste * 54)
     for i, k in ipairs(liste) do
          local sy = y + (i - 1) * 54 - kay
          if U.Gorunur(sy, 54) then
               local tik = U.Satir(x, sy, w - 10, 54, D.secili == k.id)
               U.Baklava(x + 16, sy + 27, 5, k.gorev and R.yesil or (k.cevrimici and R.altin or R.kapali), 1)
               U.Yazi(U.Kisalt(k.ad, 14, 600, w - 250), 14, 600, x + 34, sy + 19, k.cevrimici and R.fildisi or R.ada)
               U.Yazi(U.Kisalt(k.unvan .. (k.birim ~= "" and (" · " .. k.birim) or ""), 11, 700, w - 250), 11, 700, x + 34, sy + 38, R.soluk)
               KademeCiz(x + w - 190, sy + 19, k.kademe)
               U.Yazi(k.gorev and "de servicio" or (k.cevrimici and "en línea" or B.Once(k.son)), 10, 700, x + w - 190, sy + 38, k.gorev and R.yesil or R.soluk)
               U.Yazi(B.SureUzun(k.hafta), 12, 600, x + w - 24, sy + 19, R.ada, 2)
               U.Etiket("Esta semana", x + w - 24, sy + 38, R.soluk, 2, 8)
               if tik then KisiSecildi(k.id) end
          end
     end
     U.KaydirBitir()
end

local function KisiKarti(x, y, w, h, v)
     local ply = LocalPlayer()
     U.Kart(x, y, w, h)
     local k = D.secili and Bul(v, D.secili)
     if not k then return U.Bos(x, y, w, h, "Selecciona a un agente") end

     local px, pw = x + 24, w - 48
     U.Yazi(U.Kisalt(k.ad, 22, 600, pw), 22, 600, px, y + 34, R.fildisiAcik)
     U.Yazi(U.Kisalt(k.unvan, 13, 700, pw), 13, 700, px, y + 62, R.altinAcik)
     KademeCiz(px + 4, y + 86, k.kademe)
     U.Yazi(k.kademe .. ". nivel", 11, 700, px + 76, y + 86, R.soluk)

     local cy = y + 116
     cy = cy + U.Bilgi("Departamento", B.DaireAd(k.daire), px, cy, pw)
     if k.birim ~= "" then cy = cy + U.Bilgi("Unidad", k.birim, px, cy, pw) end
     cy = cy + U.Bilgi("Incorporación", B.Tarih(k.giris, false), px, cy, pw)
     cy = cy + U.Bilgi("Servicio total", B.SureUzun(k.mesai), px, cy, pw)
     cy = cy + U.Bilgi("Equipo", EkipAd(v, k.ekip) or "—", px, cy, pw, k.ekip > 0 and R.fildisi or R.soluk)

     -- eylemler
     local kisi = B.Veri["personel.kisi"]
     local hazir = kisi and kisi.id == k.id
     cy = cy + 10
     local bw = (pw - 8) / 2
     local atar = B.Yetkili(ply, "atama")
     if atar then
          local sinifVar = hazir and #kisi.siniflar > 0
          if U.Dugme(px, cy, bw, 32, "Nombrar / ascender", "ana", not sinifVar, not hazir and "Cargando…" or (not kisi.cevrimici and "La persona debe estar en línea para el nombramiento." or (not sinifVar and "No hay plazas que puedas asignar a esta persona." or nil))) then
               AtamaKipi(k, kisi.siniflar)
          end
          if U.Dugme(px + bw + 8, cy, bw, 32, "Suspender", "tehlike", not (hazir and kisi.cevrimici and #kisi.siniflar > 0)) then
               B.MetinSor("Suspender · " .. k.ad, "La persona baja a la plantilla base de la facción y se retiran las whitelists de cargos superiores. La expulsión de la facción sigue en manos de los responsables.", "Motivo…",
                    function(metin) B.Iste("personel.acigaal", {id = k.id, gerekce = metin}) end, {maks = 400, enAz = 3, dugme = "Suspender"})
          end
          cy = cy + 40
     end
     if B.Yetkili(ply, "takdir") then
          if U.Dugme(px, cy, bw, 32, "Mención honorífica", "ikincil") then
               B.MetinSor("Mención honorífica · " .. k.ad, "Se anota en el expediente de servicio y se envía a la persona como edicto.", "Motivo…", function(metin) B.Iste("personel.sicil", {id = k.id, tur = "takdir", metin = metin}) end, {cokSatir = true, maks = 400, enAz = 4})
          end
          if U.Dugme(px + bw + 8, cy, bw, 32, "Amonestación", "ikincil") then
               B.MetinSor("Amonestación · " .. k.ad, "Se anota en el expediente de servicio y se envía a la persona como edicto.", "Motivo…", function(metin) B.Iste("personel.sicil", {id = k.id, tur = "kinama", metin = metin}) end, {cokSatir = true, maks = 400, enAz = 4})
          end
          cy = cy + 40
     end
     local ekipYetki, ikramiye = B.Yetkili(ply, "ekip"), B.Yetkili(ply, "hazine_harca")
     if ekipYetki then
          if U.Dugme(px, cy, ikramiye and bw or pw, 32, "Asignar a equipo", "ikincil") then
               B.Kip({baslik = "Equipo · " .. k.ad, w = 420, ciz = function(kx, ky, kw)
                    local taze = B.Veri["personel.liste"] or v
                    local sy = ky
                    if U.Satir(kx, sy, kw, 38, k.ekip == 0) then B.Iste("ekip.uye", {id = 0, kisi = k.id}) B.KipKapat() end
                    U.Yazi("Sin equipo", 13, 600, kx + 14, sy + 19, R.ada)
                    sy = sy + 40
                    for _, e in ipairs(taze.ekipler) do
                         if U.Satir(kx, sy, kw, 38, k.ekip == e.id) then B.Iste("ekip.uye", {id = e.id, kisi = k.id}) B.KipKapat() end
                         U.Yazi(e.ad, 13, 600, kx + 14, sy + 19, R.fildisi)
                         sy = sy + 40
                    end
                    if #taze.ekipler == 0 then
                         U.Yazi("Aún no hay equipos (pestaña Equipos).", 12, 700, kx, sy + 12, R.soluk)
                         sy = sy + 34
                    end
                    return sy - ky + 6
               end})
          end
     end
     if ikramiye then
          if U.Dugme(ekipYetki and (px + bw + 8) or px, cy, ekipYetki and bw or pw, 32, "Gratificación", "ikincil", not k.cevrimici, not k.cevrimici and "La persona debe estar en línea." or "Se abona desde el Tesoro.") then
               B.MetinSor("Gratificación · " .. k.ad, "Cantidad a pagar desde el Tesoro (Galeones).", "p. ej. 150", function(metin) B.Iste("hazine.ikramiye", {kisi = k.id, miktar = tonumber(metin) or 0}) end, {sayi = true, maks = 4, dugme = "Pagar"})
          end
     end
     if ekipYetki or ikramiye then cy = cy + 40 end

     -- hizmet sicili
     cy = cy + 6
     U.Bolum("Expediente de servicio", px, cy + 10, pw)
     local ly, lh = cy + 28, y + h - (cy + 28) - 16
     if not hazir then return U.Bekleniyor(px, ly, pw, lh) end
     if #kisi.kayitlar == 0 then return U.Bos(px, ly, pw, lh, "Expediente limpio", "Los nombramientos, menciones y amonestaciones se registran aquí.") end

     local kay = U.Kaydir("personel.sicil", px, ly, pw, lh, #kisi.kayitlar * 50)
     for i, r in ipairs(kisi.kayitlar) do
          local sy = ly + (i - 1) * 50 - kay
          if U.Gorunur(sy, 50) then
               local renk = r.tur == "takdir" and R.yesil or (r.tur == "kinama" and R.kizil or R.altin)
               U.Kutu(px, sy + 4, 2, 40, renk, 0.9)
               U.Yazi(B.Buyuk(r.baslik), 10, 600, px + 12, sy + 14, renk, 0, 1.2)
               U.Yazi(B.Tarih(r.zaman, false), 10, 700, px + pw - 14, sy + 14, R.soluk, 2)
               U.Yazi(U.Kisalt(r.metin, 12, 700, pw - 30), 12, 700, px + 12, sy + 34, R.govde)
               if U.Icinde(px, sy, pw - 10, 50) then U.ipucu = r.metin .. "\n— " .. r.yazan_ad end
          end
     end
     U.KaydirBitir()
end

----------------------------------------------------------------------------------------
-- Ekipler
----------------------------------------------------------------------------------------
local function EkiplerCiz(x, y, w, h, v)
     local ply = LocalPlayer()
     local yetkili = B.Yetkili(ply, "ekip")

     U.Paragraf("Los miembros del equipo de servicio se ven entre sí a través de las paredes con una señal tenue y marcan un punto común con «objetivo de equipo».", 12, 700, x, y + 4, w - 240, R.ada, 18)
     if U.Dugme(x + w - 200, y, 200, 34, "Nuevo equipo", "ana", not yetkili, B.YetkiIpucu("ekip")) then
          B.MetinSor("Nuevo equipo", "Nombre del equipo de patrulla (p. ej. Fénix-1).", "Nombre del equipo…", function(metin) B.Iste("ekip.kur", {ad = metin}) end, {maks = 24, enAz = 2, dugme = "Crear"})
     end

     if #v.ekipler == 0 then return U.Bos(x, y + 60, w, h - 60, "No hay equipos creados") end

     local kw = (w - 2 * 20) / 3
     for i, e in ipairs(v.ekipler) do
          local kx = x + ((i - 1) % 3) * (kw + 20)
          local ky = y + 60 + math.floor((i - 1) / 3) * 232
          U.Kart(kx, ky, kw, 216)
          U.Yazi(U.Kisalt(e.ad, 18, 600, kw - 120), 18, 600, kx + 20, ky + 30, R.fildisiAcik)
          if yetkili and U.Dugme(kx + kw - 86, ky + 14, 70, 28, "Disolver", "duz") then
               B.Onay("Disolver equipo", "Se disolverá el equipo \"" .. e.ad .. "\".", "Disolver", function() B.Iste("ekip.sil", {id = e.id}) end, true)
          end
          U.SusCizgi(kx + 20, ky + 54, kw - 40, R.cizgi, 0.7)

          local n = 0
          for _, k in ipairs(v.liste) do
               if k.ekip == e.id then
                    n = n + 1
                    if n <= 5 then
                         local sy = ky + 54 + (n - 1) * 30
                         U.Baklava(kx + 28, sy + 18, 4, k.gorev and R.yesil or (k.cevrimici and R.altin or R.kapali), 1)
                         U.Yazi(U.Kisalt(k.ad, 13, 600, kw - 190), 13, 600, kx + 44, sy + 18, R.fildisi)
                         U.Yazi(U.Kisalt(k.unvan, 10, 700, 130), 10, 700, kx + kw - 20, sy + 18, R.soluk, 2)
                    end
               end
          end
          if n == 0 then U.Yazi("Sin miembros. Usa «Asignar a equipo» en la pestaña Personal.", 12, 700, kx + 20, ky + 80, R.soluk)
          elseif n > 5 then U.Yazi("+" .. (n - 5) .. " personas más", 11, 700, kx + 20, ky + 200, R.soluk) end
     end
end

local function Ciz(x, y, w, h)
     local sec = U.Sekmeler(x, y, {{id = "kadro", ad = "Personal"}, {id = "ekip", ad = "Equipos"}}, D.sekme)
     if sec then D.sekme = sec end

     local v = B.Veri["personel.liste"]
     if not v then return U.Bekleniyor(x, y + 46, w, h - 46) end

     local gy, gh = y + 52, h - 52
     if D.sekme == "ekip" then return EkiplerCiz(x, gy, w, gh, v) end

     DaireListesi(x, gy, 270, gh, v)
     KadroListesi(x + 290, gy, 560, gh, v)
     KisiKarti(x + 870, gy, w - 870, gh, v)
end

B.Sayfa("personel", {
     ad = "Personal", sira = 10, izin = "personel", kanallar = {["personel.liste"] = true},
     alt = "Departamentos, plantilla, nombramientos y expediente de servicio.",
     ac = function(arg)
          B.Sor("personel.liste", {})
          if arg.id then
               D.sekme = "kadro"
               D.daire = nil
               KisiSecildi(arg.id)
          end
     end,
     veri = function(anahtar)
          -- kadro değiştiyse seçili persona(s)nin ayrıntısı da tazelensin
          if anahtar == "personel.liste" and D.secili and RealTime() - (B.IstekAn["personel.kisi"] or 0) > 1 then B.Sor("personel.kisi", {id = D.secili}) end
     end,
     ciz = Ciz,
})
