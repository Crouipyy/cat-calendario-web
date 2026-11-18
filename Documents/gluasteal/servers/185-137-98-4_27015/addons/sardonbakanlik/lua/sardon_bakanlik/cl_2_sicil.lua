-- "addons\\sardonbakanlik\\lua\\sardon_bakanlik\\cl_2_sicil.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Expediente :: Expediente. Persona arama ve persona dosyası: sabıka, cezalar, notlar, ruhsatlar, dosyalar, emirler.

local B = SardonBakanlik
local U = B.UI
local R = U.R

local D = {sonSorgu = nil, kisi = nil, sekme = "sabika"}

local SEKMELER = {
     {id = "sabika", ad = "Antecedentes"}, {id = "ceza", ad = "Sanciones"}, {id = "not", ad = "Notas"},
     {id = "ruhsat", ad = "Registros y licencias"}, {id = "dosya", ad = "Archivo y órdenes"},
}

local function KisiAc(id)
     D.kisi = id
     D.sekme = "sabika"
     B.Veri["sicil.kisi"] = nil
     U.KaydirSifirla("sicil.kayit")
     B.Sor("sicil.kisi", {id = id})
end

local function BayrakAd(id)
     for _, b in ipairs(B.Bayraklar) do
          if b.id == id then return b.ad end
     end
     return id
end

local function AramaCiz(x, y, w, h)
     local q = string.Trim(U.Girdi("sicil.ara", x, y, w, 38, "Buscar nombre en el archivo…", {maks = 40}))
     if q ~= D.sonSorgu then
          D.sonSorgu = q
          B.Iste("sicil.ara", {q = q})
     end

     local v = B.Veri["sicil.ara"]
     local liste = v and v.liste or {}
     local ly, lh = y + 52, h - 52
     U.Etiket(q == "" and "Personajes en línea" or (#liste .. " registros"), x, ly + 4, R.soluk, 0, 10)
     ly, lh = ly + 20, lh - 20

     if #liste == 0 then return U.Bos(x, ly, w, lh, v and "No se encontró registro" or "Buscando en el archivo…") end

     local kay = U.Kaydir("sicil.liste", x, ly, w, lh, #liste * 48)
     for i, k in ipairs(liste) do
          local sy = ly + (i - 1) * 48 - kay
          if U.Gorunur(sy, 48) then
               local tik = U.Satir(x, sy, w - 8, 48, D.kisi == k.id)
               U.Baklava(x + 16, sy + 24, 4, k.cevrimici and R.yesil or R.pirinc, 1)
               U.Yazi(U.Kisalt(k.ad, 14, 600, w - 130), 14, 600, x + 32, sy + 17, R.fildisi)
               U.Yazi(U.Kisalt(k.fraksiyon or "", 11, 700, w - 130), 11, 700, x + 32, sy + 35, R.soluk)
               if k.aranan then U.Rozet("Se busca", x + w - 18, sy + 17, R.kizil, true, 2)
               elseif k.tutuklu then U.Rozet("Azkaban", x + w - 18, sy + 17, R.mor, true, 2) end
               if tik then KisiAc(k.id) end
          end
     end
     U.KaydirBitir()
end

local function KayitSatiri(x, sy, w, k)
     U.Kutu(x, sy + 3, 2, 54, k.tur == "sabika" and R.kizil or (k.tur == "ceza" and (B.DurumRenk[k.durum] or R.altin) or R.pirinc), 0.9)
     if k.tur == "ceza" then
          U.Yazi(U.Kisalt(k.baslik, 14, 600, w - 290), 14, 600, x + 16, sy + 18, R.fildisi)
          U.Yazi(B.Para(k.deger), 14, 600, x + w - 130, sy + 18, R.altinAcik, 2)
          local durumAd = ({bekliyor = "Pendiente", odendi = "Pagada", gecikti = "Vencida", itiraz = "Recurso"})[k.durum] or k.durum
          U.Rozet(durumAd, x + w - 14, sy + 18, B.DurumRenk[k.durum] or R.ada, k.durum == "gecikti", 2)
          U.Yazi(k.yazan_ad .. " · " .. B.Tarih(k.zaman), 11, 700, x + 16, sy + 40, R.soluk)
     elseif k.tur == "sabika" then
          U.Yazi(U.Kisalt(k.baslik, 13, 600, w - 40), 13, 600, x + 16, sy + 18, R.fildisi)
          U.Yazi(U.Kisalt((k.metin ~= "" and (k.metin .. " · ") or "") .. k.yazan_ad .. " · " .. B.Tarih(k.zaman) .. (k.dosya > 0 and (" · Archivo #" .. k.dosya) or ""), 11, 700, w - 40),
               11, 700, x + 16, sy + 40, R.soluk)
     elseif k.tur == "men" then
          U.Yazi("Prohibición de varita", 13, 600, x + 16, sy + 18, R.kizil)
          U.Yazi(U.Kisalt(k.metin .. " · fin " .. B.Tarih(k.bitis), 11, 700, w - 40), 11, 700, x + 16, sy + 40, R.soluk)
     else
          U.Yazi(U.Kisalt(k.metin, 13, 700, w - 40), 13, 700, x + 16, sy + 18, R.govde)
          U.Yazi(k.yazan_ad .. " · " .. B.Tarih(k.zaman), 11, 700, x + 16, sy + 40, R.soluk)
     end
     U.Kutu(x, sy + 59, w, 1, R.cizgi, 0.25)
end

local function SekmeIcerik(x, y, w, h, v)
     local ply = LocalPlayer()

     if D.sekme == "ruhsat" then
          local var = {}
          for _, k in ipairs(v.kayitlar) do
               if k.tur == "ruhsat" then var[k.baslik] = k end
          end
          local ben = B.Bilgi(ply)
          for i, r in ipairs(B.Ruhsatlar) do
               local sy = y + (i - 1) * 46
               local k = var[r.id]
               U.Kutu(x, sy + 45, w, 1, R.cizgi, 0.25)
               if k then U.Baklava(x + 14, sy + 22, 5, R.yesil, 1) else U.BaklavaCizgi(x + 14, sy + 22, 5, R.pirinc, 0.8) end
               U.Yazi(r.ad, 14, 600, x + 32, sy + 15, k and R.fildisi or R.ada)
               U.Yazi(k and (k.yazan_ad .. " · " .. B.Tarih(k.zaman, false)) or (B.DaireAd(r.daire) .. " gestiona"), 11, 700, x + 32, sy + 33, R.soluk)
               if ben and B.DaireUygun(ben, {r.daire}) and B.Yetkili(ply, "ruhsat") then
                    if U.Dugme(x + w - 130, sy + 8, 124, 30, k and "Anular" or "Guardar", k and "tehlike" or "ikincil") then
                         B.Iste("sicil.ruhsat", {id = v.id, ruhsat = r.id, ver = not k})
                    end
               end
          end
          -- Ollivanders kaydı
          local ay = y + #B.Ruhsatlar * 46 + 18
          U.Bolum("Varita registrada", x, ay + 10, w)
          if v.asa then
               U.Yazi(U.Kisalt(v.asa.agac .. " · " .. v.asa.oz, 14, 600, w - 20), 14, 600, x + 4, ay + 42, v.asa.odendi and R.fildisi or R.ada)
               U.Yazi(U.Kisalt((v.asa.uzunluk or "uzunluk sin registro") .. (v.asa.esneklik and (" · " .. v.asa.esneklik) or "") .. " · " .. (v.asa.seri or "") .. (v.asa.odendi and "" or " · tarifa impagada"), 11, 700, w - 20), 11, 700, x + 4, ay + 62, R.soluk)
          else
               U.Yazi("Sin registro en Ollivanders.", 12, 700, x + 4, ay + 42, R.soluk)
          end
          return
     end

     if D.sekme == "dosya" then
          local cy = y
          U.Bolum("Órdenes", x, cy + 10, w)
          cy = cy + 28
          if #v.emirler == 0 then
               U.Yazi("No hay órdenes vigentes o pendientes sobre esta persona.", 12, 700, x, cy + 8, R.soluk)
               cy = cy + 30
          end
          for _, e in ipairs(v.emirler) do
               U.Rozet(B.EmirTurAd[e.tur] or e.tur, x, cy + 14, e.durum == "etkin" and R.kizil or R.altinAcik, e.durum == "etkin")
               U.Yazi(U.Kisalt(e.gerekce, 12, 700, w - 330), 12, 700, x + 150, cy + 14, R.govde)
               U.Yazi((e.odul > 0 and e.tur == "aranan") and ("Recompensa " .. B.Para(e.odul)) or (e.durum == "bekliyor" and "pendiente de aprobación" or ""), 12, 600, x + w - 6, cy + 14, R.altinAcik, 2)
               cy = cy + 32
          end

          cy = cy + 14
          U.Bolum("Archivos", x, cy + 10, w)
          cy = cy + 28
          if #v.dosyalar == 0 then U.Yazi("Sospechoso olduğu dosya yok.", 12, 700, x, cy + 8, R.soluk) end
          for _, d in ipairs(v.dosyalar) do
               local tik = U.Satir(x, cy, w, 36)
               U.Yazi("#" .. d.id, 12, 600, x + 10, cy + 18, R.ust)
               U.Yazi(U.Kisalt(d.gizli == 1 and "Archivo sellado" or d.baslik, 13, 600, w - 220), 13, 600, x + 60, cy + 18, R.fildisi)
               U.Rozet(({acik = "Abierto", mahkemede = "En el Wizengamot", kapali = "Cerrado"})[d.durum] or d.durum, x + w - 10, cy + 18, B.DurumRenk[d.durum] or R.ada, false, 2)
               if tik and B.Yetkili(ply, "dosya") then B.Git("dosya", {id = d.id}) end
               cy = cy + 36
          end
          return
     end

     local liste = {}
     for _, k in ipairs(v.kayitlar) do
          if k.tur == D.sekme or (D.sekme == "sabika" and k.tur == "men") then liste[#liste + 1] = k end
     end
     if #liste == 0 then
          return U.Bos(x, y, w, h, ({sabika = "Antecedentes temiz", ceza = "Sin multas impuestas", ["not"] = "Sin notas"})[D.sekme])
     end

     local af = B.Yetkili(ply, "af")
     local kay = U.Kaydir("sicil.kayit", x, y, w, h, #liste * 60)
     for i, k in ipairs(liste) do
          local sy = y + (i - 1) * 60 - kay
          if U.Gorunur(sy, 60) then
               KayitSatiri(x, sy, w - 12, k)
               if af and (k.tur == "sabika" or k.tur == "not") and U.Icinde(x, sy, w - 12, 60) then
                    if U.Dugme(x + w - 92, sy + 30, 72, 24, "Eliminar", "tehlike") then
                         B.Onay("Eliminar registro", "Este registro se eliminará del expediente. Queda en el registro de auditoría (facultad de amnistía).", "Eliminar", function() B.Iste("sicil.kayit_sil", {id = k.id}) end, true)
                    end
               elseif k.tur == "ceza" and (k.durum == "bekliyor" or k.durum == "gecikti") and B.Yetkili(ply, "hapis_onay") and U.Icinde(x, sy, w - 12, 60) then
                    if U.Dugme(x + w - 300, sy + 30, 96, 24, "Eliminar multa", "tehlike") then B.Iste("ceza.sil", {id = k.id}) end
               end
          end
     end
     U.KaydirBitir()
end

-- Resmî tebligat: Ministerio baykuşu yazılı bir Çığırtkan götürür (sv_2sicil.lua B.Tebligat)
local function TebligatKipi(v)
     local secili = B.TebligatElle[1]
     U.GirdiAyarla("kip.tebligat", "")
     B.Kip({baslik = "Notificación oficial · " .. v.ad, w = 640, ciz = function(x, y, w)
          local h = U.Paragraf("Ministerio baykuşu kızıl bir Çığırtkan zarfı götürür. Zarf açılınca belge alıcının önünde daktiloyla yazılır, damgalanır; çevresindekiler de okur. Notificación oficial personanin siciline not olarak düşer.", 13, 700, x, y, w, R.ada, 20) + 12
          local liste = {}
          for i, id in ipairs(B.TebligatElle) do liste[i] = {id = id, ad = B.TebligatTema[id].tur} end
          local sec = U.Sekmeler(x, y + h, liste, secili)
          if sec then secili = sec end
          h = h + 50
          local metin = U.Girdi("kip.tebligat", x, y + h, w, 140, "Texto de la notificación oficial…", {cokSatir = true, maks = B.Ayar.TebligatMetin})
          local by = y + h + 140 + 18
          local yeterli = #string.Trim(metin) >= 10
          if U.Dugme(x + w - 190, by, 190, 38, "Sellar y enviar", "ana", not yeterli) then
               B.KipKapat()
               B.Iste("sicil.tebligat", {id = v.id, tema = secili, metin = string.Trim(metin)})
          end
          if U.Dugme(x + w - 330, by, 130, 38, "Cancelar", "ikincil") then B.KipKapat() end
          return by + 38 - y
     end, odak = "kip.tebligat"})
end

local function DosyaCiz(x, y, w, h)
     U.Kart(x, y, w, h)
     if not D.kisi then return U.Bos(x, y, w, h, "Selecciona una persona", "Abre un registro desde la búsqueda de la izquierda.") end

     local v = B.Veri["sicil.kisi"]
     if not v or v.id ~= D.kisi then return U.Bekleniyor(x, y, w, h) end

     local ply = LocalPlayer()
     local px, py = x + 28, y + 28
     U.Model("sicil.portre", px, py, 150, 190, v.model, v.ogr)

     local ix = px + 176
     local iw = w - 56 - 176
     U.Yazi(U.Kisalt(v.ad, 26, 600, iw - 200), 26, 600, ix, py + 16, R.fildisiAcik)
     U.Yazi(U.Kisalt(v.fraksiyon .. (v.sinif ~= "" and ("  ·  " .. v.sinif) or ""), 13, 700, iw - 170), 13, 700, ix, py + 46, R.ada)

     -- rozetler
     local rx = ix
     local function R_(metin, renk, dolu)
          rx = rx + U.Rozet(metin, rx, py + 76, renk, dolu) + 6
     end
     R_(v.cevrimici and "En línea" or "Desconectado", v.cevrimici and R.yesil or R.soluk, false)
     for _, e in ipairs(v.emirler) do
          if e.durum == "etkin" and e.tur == "aranan" then R_("Se busca", R.kizil, true) end
          if e.durum == "etkin" and e.tur == "tutuklama" then R_("Orden de detención", R.kizil, true) end
     end
     if v.tutuklu then R_("Azkaban · " .. B.Sure(v.tutuklu.kalan), R.mor, true) end
     if v.bagli then R_("Restringido", R.altinAcik, true) end
     for _, b in ipairs(v.bayraklar) do R_(BayrakAd(b), R.kizil, false) end

     local cy = py + 108
     if v.gorev then cy = cy + U.Bilgi("Cargo", v.gorev.unvan .. " · " .. B.DaireAd(v.gorev.daire, true), ix, cy, iw, R.altinAcik) end
     if v.hane ~= "" then cy = cy + U.Bilgi("Casa", v.hane, ix, cy, iw) end
     local evler = {}
     for _, e in ipairs(v.evler) do evler[#evler + 1] = "Ev No " .. e end
     cy = cy + U.Bilgi("Dirección", #evler > 0 and table.concat(evler, ", ") or "Sin vivienda registrada", ix, cy, iw, #evler > 0 and R.fildisi or R.soluk)
     if v.onur then cy = cy + U.Bilgi("Honor", v.onur, ix, cy, iw) end
     if not v.cevrimici and v.son > 0 then U.Bilgi("Última vez visto", B.Tarih(v.son), ix, cy, iw, R.soluk) end

     -- eylemler
     local bx = x + w - 28
     local function Eylem(ad, genislik, stil, izin, fn)
          bx = bx - genislik
          local yetkili = B.Yetkili(ply, izin)
          if yetkili and U.Dugme(bx, py, genislik, 32, ad, stil, false, B.YetkiIpucu(izin)) then fn() end
          if yetkili then bx = bx - 8 else bx = bx + genislik end
     end
     Eylem("Añadir nota", 110, "ana", "sicil_not", function()
          B.MetinSor("Añadir nota al expediente", v.ad .. " — observación, advertencia o información.", "Nota…", function(metin) B.Iste("sicil.not", {id = v.id, metin = metin}) end, {cokSatir = true, maks = 400, enAz = 3})
     end)
     Eylem("Abrir archivo", 110, "ikincil", "dosya", function()
          B.MetinSor("Nuevo soruşturma dosyası", "Sospechoso: " .. v.ad, "Título del archivo…", function(metin) B.Iste("dosya.ac", {baslik = metin, supheli = v.id}) end, {maks = 80, enAz = 3, dugme = "Abrir archivo"})
     end)
     Eylem("Solicitar orden", 110, "ikincil", "emir_iste", function() B.Git("emir", {yeni = {hedef = v.id, ad = v.ad}}) end)
     -- tebligat: ikinci sıra (üst sıra dolu)
     if B.Yetkili(ply, "tebligat") then
          local kapali = not v.cevrimici
          if U.Dugme(x + w - 28 - 150, py + 42, 150, 30, "Notificación oficial", "ikincil", kapali, kapali and "Para notificación oficial la persona debe estar conectada." or B.YetkiIpucu("tebligat")) then
               TebligatKipi(v)
          end
     end
     Eylem("Bayrak", 96, "ikincil", "sicil_bayrak", function()
          B.Kip({baslik = "Marcadores del expediente", w = 420, ciz = function(kx, ky, kw)
               local taze = B.Veri["sicil.kisi"] or v
               local acik = {}
               for _, b in ipairs(taze.bayraklar) do acik[b] = true end
               for i, b in ipairs(B.Bayraklar) do
                    if U.Kutucuk(kx, ky + 8 + (i - 1) * 34, b.ad, acik[b.id]) then B.Iste("sicil.bayrak", {id = v.id, bayrak = b.id}) end
               end
               local by = ky + #B.Bayraklar * 34 + 14
               if U.Dugme(kx + kw - 130, by, 130, 36, "Aceptar", "ana") then B.KipKapat() end
               return by + 36 - ky
          end})
     end)

     -- sekmeler
     local sy = py + 214
     local sayilar = {}
     for _, k in ipairs(v.kayitlar) do sayilar[k.tur] = (sayilar[k.tur] or 0) + 1 end
     local sekmeler = {}
     for i, s in ipairs(SEKMELER) do
          sekmeler[i] = {id = s.id, ad = s.ad, rozet = (s.id == "sabika" or s.id == "ceza" or s.id == "not") and sayilar[s.id] or nil}
     end
     local sec = U.Sekmeler(px, sy, sekmeler, D.sekme)
     if sec then
          D.sekme = sec
          U.KaydirSifirla("sicil.kayit")
     end

     SekmeIcerik(px, sy + 48, w - 56, y + h - (sy + 48) - 20, v)
end

local function Ciz(x, y, w, h)
     AramaCiz(x, y + 6, 380, h - 6)
     DosyaCiz(x + 404, y + 6, w - 404, h - 6)
end

B.EmirTurAd = {aranan = "Se busca", arama = "Orden de registro", tutuklama = "Orden de detención", hapis = "Aprobación de reclusión"}

B.Sayfa("sicil", {
     ad = "Expediente", sira = 3, izin = "sicil", kanallar = {["sicil.kisi"] = true},
     alt = "Archivo de magos: quién es, dónde vive y antecedentes.",
     ac = function(arg)
          D.sonSorgu = nil
          if arg.kisi then KisiAc(arg.kisi) end
     end,
     veri = function(anahtar, tablo)
          if anahtar == "dosya.acildi" then B.Git("dosya", {id = tablo.id}) end
     end,
     ciz = Ciz,
})
