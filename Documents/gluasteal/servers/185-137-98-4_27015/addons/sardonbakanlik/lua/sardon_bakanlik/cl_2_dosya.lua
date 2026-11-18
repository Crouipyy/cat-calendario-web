-- "addons\\sardonbakanlik\\lua\\sardon_bakanlik\\cl_2_dosya.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Expediente :: Archivos. Soruşturma dosyası: şüpheliler, ceza kanunundan suçlamalar, deliller,
-- kademeli ceza (doğrudan / amir onayı / Wizengamot).

local B = SardonBakanlik
local U = B.UI
local R = U.R

local D = {durum = "acik", sonSorgu = "", id = nil}

local DURUM_AD = {acik = "Abierto", mahkemede = "En el Wizengamot", kapali = "Cerrado"}
local DELIL_RENK = {priori = R.mor, ani = R.mavi, foto = R.ada, esya = R.altinAcik, ifade = R.govde}
B.DelilTurAd = {priori = "Examen de varita", ani = "Botella de recuerdo", foto = "Fotografía", esya = "Objeto confiscado", ifade = "Declaración"}

local function ListeIste()
     B.Sor("dosya.liste", {durum = D.durum, q = D.sonSorgu})
end

local function DosyaAc(id)
     D.id = id
     B.SonDosya = id -- L menüsündeki asa incelemesi / üst arama bu dosyaya delil yazar
     B.Veri["dosya.getir"] = nil
     U.KaydirSifirla("dosya.delil")
     U.KaydirSifirla("dosya.suc")
     B.Sor("dosya.getir", {id = id})
end

----------------------------------------------------------------------------------------
-- Liste
----------------------------------------------------------------------------------------
local function ListeCiz(x, y, w, h)
     local sec = U.Sekmeler(x, y, {{id = "acik", ad = "Abierto"}, {id = "mahkemede", ad = "En el Wizengamot"}, {id = "kapali", ad = "Cerrado"}, {id = "hepsi", ad = "Todos"}}, D.durum)
     if sec then
          D.durum = sec
          U.KaydirSifirla("dosya.liste")
          ListeIste()
     end

     local q = string.Trim(U.Girdi("dosya.ara", x + w - 520, y - 2, 300, 34, "Buscar título o sospechoso…", {maks = 40}))
     if q ~= D.sonSorgu then
          D.sonSorgu = q
          ListeIste()
     end

     if U.Dugme(x + w - 200, y - 2, 200, 34, "Nuevo archivo", "ana") then
          B.MetinSor("Nuevo expediente de investigación", "Añadirás sospechoso, cargos y pruebas tras abrir el expediente.", "Título del expediente…",
               function(metin) B.Iste("dosya.ac", {baslik = metin}) end, {maks = 80, enAz = 3, dugme = "Abrir expediente"})
     end

     local v = B.Veri["dosya.liste"]
     local gy, gh = y + 56, h - 56
     if not v then return U.Bekleniyor(x, gy, w, gh) end
     if #v.liste == 0 then return U.Bos(x, gy, w, gh, "No hay archivos en este estante", "Puedes convertir un incidente en expediente desde Incidentes o abrir uno nuevo.") end

     U.Etiket("No", x + 14, gy + 8, R.soluk, 0, 9)
     U.Etiket("Expediente", x + 80, gy + 8, R.soluk, 0, 9)
     U.Etiket("Sospechoso", x + 560, gy + 8, R.soluk, 0, 9)
     U.Etiket("Responsable", x + 860, gy + 8, R.soluk, 0, 9)
     U.Etiket("Prueba", x + 1090, gy + 8, R.soluk, 0, 9)
     U.Etiket("Actualización", x + w - 16, gy + 8, R.soluk, 2, 9)

     local ly, lh = gy + 24, gh - 24
     local kay = U.Kaydir("dosya.liste", x, ly, w, lh, #v.liste * 56)
     for i, d in ipairs(v.liste) do
          local sy = ly + (i - 1) * 56 - kay
          if U.Gorunur(sy, 56) then
               local tik = U.Satir(x, sy, w - 8, 56)
               U.Yazi("#" .. d.id, 13, 600, x + 14, sy + 28, R.ust)
               U.Yazi(U.Kisalt(d.baslik, 15, 600, 330), 15, 600, x + 80, sy + 20, R.fildisi)
               local rx = x + 80 + U.Rozet(DURUM_AD[d.durum] or d.durum, x + 80, sy + 42, B.DurumRenk[d.durum] or R.ada) + 6
               if d.gizli then U.Rozet("Sellado", rx, sy + 42, R.kizil, true) end
               U.Yazi(U.Kisalt(d.supheli ~= "" and d.supheli or "—", 13, 700, 280), 13, 700, x + 560, sy + 28, d.supheli ~= "" and R.govde or R.soluk)
               U.Yazi(U.Kisalt(d.sorumlu_ad, 13, 700, 210), 13, 700, x + 860, sy + 28, R.ada)
               U.Yazi(d.delil, 13, 600, x + 1090, sy + 28, d.delil > 0 and R.fildisi or R.soluk)
               U.Yazi(B.Once(d.guncelleme), 12, 700, x + w - 24, sy + 28, R.soluk, 2)
               if tik then DosyaAc(d.id) end
          end
     end
     U.KaydirBitir()
end

----------------------------------------------------------------------------------------
-- Delil ekleme kipi
----------------------------------------------------------------------------------------
local function EnvanterEsyalari(tur)
     local liste = {}
     local char = LocalPlayer():GetCharacter()
     local inv = char and char:GetInventory()
     if not inv then return liste end

     for _, item in pairs(inv:GetItems()) do
          local uid = string.lower(item.uniqueID or "")
          if tur == "ani" and uid == "ani_sisesi" and item:GetData("ani") then
               local etiket = item:GetData("baslik", "")
               liste[#liste + 1] = {id = item:GetID(), ad = etiket ~= "" and etiket or "Recuerdo", alt = "De: " .. tostring(item:GetData("sahip", "?"))}
          elseif tur == "foto" and uid == "polaroidphoto" and item:GetData("Image") then
               liste[#liste + 1] = {id = item:GetID(), ad = "Fotografía", alt = "Kod: " .. tostring(item:GetData("Image"))}
          end
     end
     return liste
end

local function DelilKipi(dosyaId)
     local tur, secili = "ifade", nil
     local TURLER = {{id = "ifade", ad = "Declaración / tutanak"}, {id = "esya", ad = "Objeto confiscado"}, {id = "ani", ad = "Botella de recuerdo"}, {id = "foto", ad = "Fotografía"}}

     B.Kip({baslik = "Añadir prueba al archivo", w = 640, ciz = function(x, y, w)
          local bw = (w - 3 * 8) / 4
          for i, t in ipairs(TURLER) do
               local bx = x + (i - 1) * (bw + 8)
               local sec = tur == t.id
               local ustunde = U.Icinde(bx, y, bw, 36)
               U.Kutu(bx, y, bw, 36, R.altin, sec and 0.24 or (ustunde and 0.1 or 0.03))
               U.Cerceve(bx, y, bw, 36, sec and R.altinAcik or R.cizgi, 0.85)
               U.Yazi(B.Buyuk(t.ad), 10, 600, bx + bw / 2, y + 18, sec and R.fildisiAcik or R.ada, 1, 1.2)
               if ustunde then
                    U.imlec = true
                    if U.Tik(bx, y, bw, 36) then tur, secili = t.id, nil end
               end
          end

          local cy = y + 52
          local baslik = U.Girdi("kip.baslik", x, cy, w, 36, "Nombre de la prueba (opcional)", {maks = 80})
          cy = cy + 46

          local hazir = false
          if tur == "ifade" or tur == "esya" then
               local metin = U.Girdi("kip.metin", x, cy, w, 150, tur == "ifade" and "Quién dijo qué, qué se vio…" or "Qué se encontró y en poder de quién…", {cokSatir = true, maks = 1200})
               hazir = #string.Trim(metin) >= 5
               cy = cy + 160
          else
               local esyalar = EnvanterEsyalari(tur)
               U.Etiket(tur == "ani" and "Frascos de recuerdo llenos en el inventario" or "Fotos en el inventario", x, cy + 6, R.soluk, 0, 9)
               cy = cy + 20
               if #esyalar == 0 then
                    U.Bos(x, cy, w, 130, "No tienes el objeto adecuado en el inventario", tur == "ani" and "Debes llevar una botella llena con Memoria Argentea." or "Debes llevar una foto hecha con polaroid.")
               else
                    local kay = U.Kaydir("kip.esya", x, cy, w, 130, #esyalar * 42)
                    for i, e in ipairs(esyalar) do
                         local sy = cy + (i - 1) * 42 - kay
                         if U.Gorunur(sy, 42) then
                              if U.Satir(x, sy, w - 8, 42, secili == e.id) then secili = e.id end
                              U.Yazi(U.Kisalt(e.ad, 14, 600, 300), 14, 600, x + 14, sy + 21, R.fildisi)
                              U.Yazi(U.Kisalt(e.alt, 11, 700, 240), 11, 700, x + w - 20, sy + 21, R.soluk, 2)
                         end
                    end
                    U.KaydirBitir()
               end
               hazir = secili ~= nil
               cy = cy + 140
               if tur == "ani" then
                    U.Yazi("Conservas la botella; en la vista el presidente puede proyectar el recuerdo en sala.", 11, 700, x, cy + 4, R.soluk)
                    cy = cy + 18
               end
          end

          cy = cy + 12
          if U.Dugme(x + w - 170, cy, 170, 38, "Añadir al archivo", "ana", not hazir) then
               B.Iste("dosya.delil", {id = dosyaId, tur = tur, baslik = baslik, metin = U.GirdiDeger("kip.metin"), item = secili})
               B.KipKapat()
          end
          if U.Dugme(x + w - 310, cy, 130, 38, "Cancelar", "ikincil") then B.KipKapat() end
          return cy + 38 - y
     end})
end

----------------------------------------------------------------------------------------
-- Ayrıntı
----------------------------------------------------------------------------------------
local function SolSutun(x, y, w, h, v)
     local ply = LocalPlayer()
     local cy = y

     -- özet
     U.Bolum("Resumen", x, cy + 10, w)
     if v.duzenler and U.Dugme(x + w - 90, cy - 2, 90, 24, "Editar", "duz") then
          B.MetinSor("Resumen del expediente", nil, "Resumen del suceso…", function(metin) B.Iste("dosya.guncelle", {id = v.id, ozet = metin}) end, {cokSatir = true, deger = v.ozet, maks = 1200, enAz = 0})
     end
     cy = cy + 30
     if v.ozet == "" then
          U.Yazi("Sin resumen escrito.", 13, 700, x, cy + 8, R.soluk)
          cy = cy + 30
     else
          cy = cy + U.Paragraf(v.ozet, 13, 700, x, cy, w, R.govde, 20, 5) + 10
     end

     -- şüpheliler
     cy = cy + 8
     U.Bolum("Sospechosos", x, cy + 10, w)
     if v.duzenler and U.Dugme(x + w - 130, cy - 2, 130, 24, "Añadir sospechoso", "duz") then
          B.KisiSec("Añadir sospechoso", function(id) B.Iste("dosya.supheli", {id = v.id, kisi = id, ekle = true}) end)
     end
     cy = cy + 28
     if #v.supheliler == 0 then
          U.Yazi("Ningún sospechoso añadido.", 13, 700, x, cy + 8, R.soluk)
          cy = cy + 30
     end
     local onayGerek = v.hapis > B.Ayar.DogrudanHapis and not B.Yetkili(ply, "hapis_onay")
     for _, s in ipairs(v.supheliler) do
          local ustunde = U.Icinde(x, cy, w, 40)
          U.Kutu(x, cy + 39, w, 1, R.cizgi, 0.25)
          if ustunde then U.Kutu(x, cy, w, 40, R.altin, 0.05) end
          U.Baklava(x + 10, cy + 20, 4, R.kizil, 0.9)
          U.Yazi(U.Kisalt(s.ad, 14, 600, w - 380), 14, 600, x + 26, cy + 20, R.fildisi)

          local bx = x + w
          if v.duzenler then
               bx = bx - 30
               if U.Dugme(bx, cy + 6, 28, 28, "×", "duz", false, "Quitar al sospechoso del expediente") then B.Iste("dosya.supheli", {id = v.id, kisi = s.id, ekle = false}) end
          end
          bx = bx - 78
          if U.Dugme(bx, cy + 6, 72, 28, "Expediente", "duz") then B.Git("sicil", {kisi = s.id}) end
          if v.durum ~= "kapali" and #v.suclamalar > 0 and B.Yetkili(ply, "hapis") then
               if onayGerek then
                    bx = bx - 124
                    if U.Dugme(bx, cy + 6, 118, 28, "Solicitar aprobación", "ikincil", false, B.SureUzun(v.hapis) .. " de prisión superan el límite de " .. B.SureUzun(B.Ayar.DogrudanHapis) .. ": hace falta la aprobación de un superior.") then
                         B.Iste("ceza.onay_iste", {dosya = v.id, hedef = s.id})
                    end
               end
               bx = bx - 144
               if U.Dugme(bx, cy + 6, 138, 28, "Aplicar sanción", "ana", false, "El sospechoso debe estar atado y a tu lado. Se aplica la multa; si hay prisión, se envía a Azkaban.") then
                    B.Onay("Aplicar sanción", "Se aplicará al expediente la sanción por los cargos de " .. s.ad .. ":\n" ..
                         (v.para > 0 and (B.Para(v.para) .. " de multa") or "") .. ((v.para > 0 and v.hapis > 0) and " y " or "") ..
                         (v.hapis > 0 and (B.SureUzun(v.hapis) .. " en Azkaban") or "") .. ".\nEl sospechoso debe estar atado y a tu lado.", "Aplicar",
                         function() B.Iste("ceza.uygula", {dosya = v.id, hedef = s.id}) end, true)
               end
          end
          cy = cy + 40
     end

     -- deliller
     cy = cy + 14
     U.Bolum("Pruebas", x, cy + 10, w, #v.deliller > 0 and (#v.deliller .. " partidas") or nil)
     if v.duzenler and U.Dugme(x + w - 110 - (#v.deliller > 0 and 80 or 0), cy - 2, 110, 24, "Añadir prueba", "duz") then DelilKipi(v.id) end
     cy = cy + 28

     local lh = y + h - cy
     if #v.deliller == 0 then
          return U.Bos(x, cy, w, lh, "Sin pruebas", "Añade examen de varita, frasco de recuerdo, fotografía, objeto confiscado o declaración.")
     end

     local ben = LocalPlayer():GetCharacter() and LocalPlayer():GetCharacter():GetID() or 0
     local toplam = 0
     local yukseklikler = {}
     for i, d in ipairs(v.deliller) do
          yukseklikler[i] = 50 + (d.metin ~= "" and U.ParagrafH(d.metin, 12, 700, w - 44, 17, d.tur == "priori" and 10 or 3) or 0)
          toplam = toplam + yukseklikler[i] + 8
     end

     local kay = U.Kaydir("dosya.delil", x, cy, w, lh, toplam)
     local sy = cy - kay
     for i, d in ipairs(v.deliller) do
          local dh = yukseklikler[i]
          if U.Gorunur(sy, dh) then
               local renk = DELIL_RENK[d.tur] or R.ada
               U.Kutu(x, sy, w - 12, dh, R.zeminKoyu, 0.5)
               U.Kutu(x, sy, 2, dh, renk, 0.9)
               U.Rozet(B.DelilTurAd[d.tur] or d.tur, x + 14, sy + 16, renk)
               U.Yazi(U.Kisalt(d.baslik, 13, 600, w - 330), 13, 600, x + 150, sy + 16, R.fildisi)
               U.Yazi(d.ekleyen_ad .. " · " .. B.Tarih(d.zaman), 10, 700, x + w - 24 - (v.duzenler and 30 or 0), sy + 16, R.soluk, 2)
               if d.metin ~= "" then U.Paragraf(d.metin, 12, 700, x + 14, sy + 32, w - 44, R.govde, 17, d.tur == "priori" and 10 or 3) end
               if v.duzenler and (d.ekleyen == ben or B.Kademe(ply) >= 4) and U.Icinde(x, sy, w - 12, dh) then
                    if U.Dugme(x + w - 42, sy + 4, 24, 24, "×", "duz", false, "Quitar la prueba del expediente") then B.Iste("dosya.delil_sil", {id = d.id}) end
               end
          end
          sy = sy + dh + 8
     end
     U.KaydirBitir()
end

local function SagSutun(x, y, w, h, v)
     local ply = LocalPlayer()
     local carpan = GetGlobalFloat("SBCezaCarpani", 1)

     U.Bolum("Cargos", x, y + 10, w)
     if v.duzenler and U.Dugme(x + w - 120, y - 2, 120, 24, "Añadir artículo", "duz") then
          B.KanunSec("Añadir artículo del código penal", function(kod)
               local adet = 1
               for _, s in ipairs((B.Veri["dosya.getir"] or v).suclamalar) do
                    if s.kod == kod then adet = s.adet + 1 end
               end
               B.Iste("dosya.suclama", {id = v.id, kod = kod, adet = adet})
          end)
     end

     local ly = y + 30
     local altH = 250
     local lh = h - 30 - altH
     if #v.suclamalar == 0 then
          U.Bos(x, ly, w, lh, "Sin cargos", "Añade artículos del código penal; multa y prisión se totalizan solas.")
     else
          local kay = U.Kaydir("dosya.suc", x, ly, w, lh, #v.suclamalar * 54)
          for i, s in ipairs(v.suclamalar) do
               local sy = ly + (i - 1) * 54 - kay
               local m = B.KanunIndex[s.kod]
               if m and U.Gorunur(sy, 54) then
                    U.Kutu(x, sy + 53, w - 12, 1, R.cizgi, 0.25)
                    U.Yazi(m.kod, 11, 600, x + 4, sy + 18, R.ust, 0, 1.2)
                    U.Yazi(U.Kisalt(m.ad, 14, 600, w - 300), 14, 600, x + 60, sy + 18, R.fildisi)
                    local ceza = (m.para > 0 and B.Para(math.floor(m.para * carpan) * s.adet) or "") .. ((m.para > 0 and m.hapis > 0) and "  ·  " or "") ..
                         (m.hapis > 0 and B.SureUzun(m.hapis * s.adet) or "")
                    U.Yazi(ceza, 12, 700, x + 60, sy + 38, m.agir >= 3 and R.kizil or R.ada)
                    if U.Icinde(x, sy, w - 12, 54) then U.ipucu = m.aciklama end

                    if v.duzenler then
                         local bx = x + w - 12 - 100
                         if U.Dugme(bx, sy + 12, 28, 28, "−", "ikincil") then B.Iste("dosya.suclama", {id = v.id, kod = s.kod, adet = s.adet - 1}) end
                         U.Yazi("×" .. s.adet, 13, 600, bx + 50, sy + 26, R.fildisi, 1)
                         if U.Dugme(bx + 72, sy + 12, 28, 28, "+", "ikincil", s.adet >= 9) then B.Iste("dosya.suclama", {id = v.id, kod = s.kod, adet = s.adet + 1}) end
                    else
                         U.Yazi("×" .. s.adet, 13, 600, x + w - 30, sy + 26, R.fildisi, 2)
                    end
               end
          end
          U.KaydirBitir()
     end

     -- toplam + hüküm + eylemler
     local ty = y + h - altH + 12
     U.Kart(x, ty, w, 118, true)
     U.Etiket("Total del código penal", x + 20, ty + 22, R.ust)
     U.Yazi(B.Para(v.para), 24, 600, x + 20, ty + 56, R.fildisiAcik)
     U.Etiket("Multa", x + 20, ty + 84, R.soluk, 0, 9)
     U.Yazi(v.hapis > 0 and B.SureUzun(v.hapis) or "—", 24, 600, x + 250, ty + 56, v.hapis > B.Ayar.DogrudanHapis and R.kizil or R.fildisiAcik)
     U.Etiket("Azkaban", x + 250, ty + 84, R.soluk, 0, 9)

     local yol
     if v.hapis <= 0 then yol = "Sin prisión: el agente puede aplicar la sanción directamente."
     elseif v.hapis <= B.Ayar.DogrudanHapis then yol = "Prisión breve: el agente puede aplicarla directamente."
     else yol = "Pena grave: hace falta aprobación de un superior o sentencia del Wizengamot." end
     for i, s in ipairs(U.Sar(yol, 12, 700, w - 470)) do U.Yazi(s, 12, 700, x + 440, ty + 34 + i * 18, R.ada) end
     if carpan ~= 1 then U.Yazi("Factor del decreto: %" .. math.Round(carpan * 100), 11, 700, x + 440, ty + 96, R.altinAcik) end

     local hy = ty + 132
     if v.hukum ~= "" then
          U.Etiket("Sentencia", x, hy + 6, R.ust)
          U.Yazi(U.Kisalt(v.hukum, 13, 600, w - 80), 13, 600, x + 76, hy + 6, R.fildisi)
     elseif v.durusma and v.durusma.durum ~= "bitti" then
          U.Etiket("Vista en curso", x, hy + 6, R.mor)
          U.Yazi("Presidente: " .. v.durusma.baskan_ad, 13, 700, x + 170, hy + 6, R.govde)
     end

     local by = y + h - 42
     if v.durum == "acik" then
          if U.Dugme(x, by, 230, 38, "Remitir al Wizengamot", "ana", #v.supheliler == 0 or #v.suclamalar == 0, "Hace falta al menos un sospechoso y un cargo. El expediente pasa a la cola de vista.") then
               B.Onay("Remisión al Wizengamot", "El expediente entrará en la cola de vista. Hasta que un superior de 4.ª categoría abra la vista, aún se pueden aplicar sanciones sobre el expediente.", "Remitir",
                    function() B.Iste("dosya.durum", {id = v.id, durum = "mahkemede"}) end)
          end
          if U.Dugme(x + w - 170, by, 170, 38, "Cerrar expediente", "tehlike") then
               B.MetinSor("Cerrar expediente", "El resultado queda registrado en el expediente. Cerrado no se puede modificar (sí reabrir).", "Resultado…",
                    function(metin) B.Iste("dosya.durum", {id = v.id, durum = "kapali", sonuc = metin}) end, {maks = 400, enAz = 0, dugme = "Cerrar"})
          end
     elseif v.durum == "mahkemede" then
          if U.Dugme(x, by, 230, 38, "Ir al Wizengamot", "ana") then B.Git("mahkeme") end
          if U.Dugme(x + w - 170, by, 170, 38, "Retirar", "ikincil") then B.Iste("dosya.durum", {id = v.id, durum = "acik"}) end
     else
          if U.Dugme(x, by, 200, 38, "Reabrir", "ikincil") then B.Iste("dosya.durum", {id = v.id, durum = "acik"}) end
     end
end

local function AyrintiCiz(x, y, w, h)
     if U.Dugme(x, y, 130, 32, "‹  Archivos", "duz") then
          D.id = nil
          ListeIste()
          return
     end

     local v = B.Veri["dosya.getir"]
     if not v or v.id ~= D.id then return U.Bekleniyor(x, y + 40, w, h - 40) end
     local ply = LocalPlayer()

     U.Yazi("#" .. v.id, 20, 600, x + 150, y + 16, R.ust)
     local bx = x + 160 + U.Olc("#" .. v.id, 20, 600)
     U.Yazi(U.Kisalt(v.baslik, 20, 600, 560), 20, 600, bx, y + 16, R.fildisiAcik)
     bx = bx + U.Olc(U.Kisalt(v.baslik, 20, 600, 560), 20, 600) + 16
     bx = bx + U.Rozet(DURUM_AD[v.durum] or v.durum, bx, y + 17, B.DurumRenk[v.durum] or R.ada, true) + 6
     if v.gizli then bx = bx + U.Rozet("Sellado", bx, y + 17, R.kizil, true) + 6 end

     local sx = x + w
     if v.duzenler then
          sx = sx - 110
          if U.Dugme(sx, y, 110, 32, "Título", "duz") then
               B.MetinSor("Título del expediente", nil, "Título…", function(metin) B.Iste("dosya.guncelle", {id = v.id, baslik = metin}) end, {deger = v.baslik, maks = 80, enAz = 3})
          end
          if B.Yetkili(ply, "dosya_gizli") then
               sx = sx - 140
               if U.Dugme(sx, y, 132, 32, v.gizli and "Quitar sello" or "Sellar", "duz", false, "El expediente sellado solo lo ven el responsable y superiores de 4.ª categoría.") then
                    B.Iste("dosya.guncelle", {id = v.id, gizli = not v.gizli})
                    if not v.gizli then U.MuhurBas(x + w - 200, y + 60) end
               end
          end
     end
     U.Yazi("Responsable: " .. v.sorumlu_ad .. "  ·  apertura " .. B.Tarih(v.zaman, false), 12, 700, sx - 16, y + 16, R.soluk, 2)

     U.Gecis(x, y + 42, w, 1, R.cizgi, 0.6, "l")
     SolSutun(x, y + 56, 630, h - 56, v)
     U.Kutu(x + 652, y + 56, 1, h - 56, R.cizgi, 0.3)
     SagSutun(x + 676, y + 56, w - 676, h - 56, v)
end

local function Ciz(x, y, w, h)
     if D.id then AyrintiCiz(x, y + 6, w, h - 6) else ListeCiz(x, y, w, h) end
end

B.Sayfa("dosya", {
     ad = "Archivos", sira = 4, izin = "dosya", rozet = "dosya", kanallar = {["dosya.getir"] = true, ["dosya.liste"] = true},
     alt = "Expedientes de investigación: sospechoso, cargo, prueba.",
     ac = function(arg)
          if arg.id then DosyaAc(arg.id) else D.id = nil ListeIste() end
     end,
     veri = function(anahtar, tablo)
          if anahtar == "dosya.acildi" then DosyaAc(tablo.id) end
     end,
     geri = function()
          if D.id then
               D.id = nil
               ListeIste()
               return true
          end
     end,
     ciz = Ciz,
})
