-- "addons\\sardonbakanlik\\lua\\sardon_bakanlik\\cl_2_masa.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sicil Defteri :: Daire Masası. Her dairenin kendi işi: ulaşım, yaratıklar, kazalar, oyunlar, esrar, makam.

local B = SardonBakanlik
local U = B.UI
local R = U.R

local D = {daire = nil, ruhsat = nil}
local alinma = 0

local function Dairelerim()
     local b = B.Bilgi(LocalPlayer())
     local liste = {}
     if not b then return liste end
     for _, d in ipairs(B.Daireler) do
          if d.id ~= "yasa" and B.DaireUygun(b, {d.id}) then liste[#liste + 1] = d end
     end
     return liste
end

local function Iste()
     if D.daire then B.Sor("masa.durum", {daire = D.daire}) end
end

local function KayitAc(ruhsat)
     D.ruhsat = ruhsat
     B.Veri["masa.kayitlar"] = nil
     B.Sor("masa.kayitlar", {ruhsat = ruhsat})
end

-- Ruhsat sayım kutuları + seçili kaydın sahipleri. Dönüş: kullanılan yükseklik
local function Ruhsatlar(x, y, w, h, v)
     local ply = LocalPlayer()
     U.Bolum("Registros y licencias", x, y + 10, w)
     local kw = (w - (#v.ruhsatlar - 1) * 12) / math.max(1, #v.ruhsatlar)
     for i, r in ipairs(v.ruhsatlar) do
          local kx = x + (i - 1) * (kw + 12)
          local sec = D.ruhsat == r.id
          local ustunde = U.Icinde(kx, y + 30, kw, 76)
          U.Kart(kx, y + 30, kw, 76, sec or ustunde)
          U.Yazi(r.n, 26, 600, kx + 18, y + 60, R.fildisiAcik)
          U.Etiket(r.ad, kx + 18, y + 90, R.ust, 0, 9)
          if ustunde then
               U.imlec = true
               if U.Tik(kx, y + 30, kw, 76) then KayitAc(r.id) end
          end
     end

     local ly = y + 124
     local lh = h - 124
     local k = B.Veri["masa.kayitlar"]
     if not D.ruhsat then return U.Bos(x, ly, w, lh, "Elige un tipo de registro", "Haz clic en uno de los recuadros de arriba para ver los titulares.") end
     if not k or k.ruhsat ~= D.ruhsat then return U.Bekleniyor(x, ly, w, lh) end

     U.Yazi(k.ad, 15, 600, x, ly + 12, R.fildisi)
     if B.Yetkili(ply, "ruhsat") and U.Dugme(x + w - 170, ly - 2, 170, 30, "Añadir registro", "ikincil", false, B.YetkiIpucu("ruhsat")) then
          B.KisiSec(k.ad .. ": ¿a quién?", function(id) B.Iste("sicil.ruhsat", {id = id, ruhsat = D.ruhsat, ver = true}) end)
     end
     ly, lh = ly + 36, lh - 36
     if #k.liste == 0 then return U.Bos(x, ly, w, lh, "Nadie registrado") end

     local kay = U.Kaydir("masa.kayit", x, ly, w, lh, #k.liste * 40)
     for i, r in ipairs(k.liste) do
          local sy = ly + (i - 1) * 40 - kay
          if U.Gorunur(sy, 40) then
               -- Satir consumes U.Tik for the whole row; Anular must claim the click first.
               local ustunde = U.Icinde(x, sy, w - 10, 40)
               if ustunde then
                    U.Kutu(x, sy, w - 10, 40, R.altin, 0.07)
                    U.imlec = true
               end
               U.Kutu(x, sy + 39, w - 10, 1, R.cizgi, 0.28)
               U.Baklava(x + 14, sy + 20, 4, R.yesil, 1)
               U.Yazi(U.Kisalt(r.ad, 14, 600, w - 420), 14, 600, x + 30, sy + 20, R.fildisi)
               local anular = ustunde and B.Yetkili(ply, "ruhsat")
               if not anular then
                    U.Yazi(r.yazan_ad .. " · " .. B.Tarih(r.zaman, false), 11, 700, x + w - 20, sy + 20, R.soluk, 2)
               else
                    U.Yazi(r.yazan_ad .. " · " .. B.Tarih(r.zaman, false), 11, 700, x + w - 210, sy + 20, R.soluk, 2)
                    if U.Dugme(x + w - 110, sy + 6, 90, 28, "Revocar", "tehlike") then
                         B.Iste("sicil.ruhsat", {id = r.kisi, ruhsat = D.ruhsat, ver = false})
                         B.Veri["masa.kayitlar"] = nil
                         B.Sor("masa.kayitlar", {ruhsat = D.ruhsat})
                    end
               end
               if (not anular) and ustunde and U.Tik(x, sy, w - 10, 40) and B.Yetkili(ply, "sicil") then
                    U.Ses("uzeri")
                    B.Git("sicil", {kisi = r.kisi})
               end
          end
     end
     U.KaydirBitir()
end

local function OlayListesi(x, y, w, h, olaylar, baslik, bos)
     U.Bolum(baslik, x, y + 10, w, #olaylar > 0 and (#olaylar .. " abiertos") or nil)
     local ly, lh = y + 30, h - 30
     if #olaylar == 0 then return U.Bos(x, ly, w, lh, bos) end
     for i, o in ipairs(olaylar) do
          local sy = ly + (i - 1) * 50
          if sy + 50 <= ly + lh then
               local tik = U.Satir(x, sy, w, 50)
               U.Baklava(x + 14, sy + 25, 5, B.DurumRenk[o.durum] or R.ada, 1)
               U.Yazi(U.Kisalt(o.baslik, 14, 600, w - 170), 14, 600, x + 32, sy + 17, R.fildisi)
               U.Yazi(U.Kisalt(o.bolge, 11, 700, w - 170), 11, 700, x + 32, sy + 36, R.soluk)
               U.Yazi(B.Once(o.zaman), 11, 700, x + w - 14, sy + 25, R.soluk, 2)
               if tik then B.Git("olay", {id = o.id}) end
          end
     end
end

local MASA = {}

MASA.ulasim = function(x, y, w, h, v)
     local p = v.portkey
     U.Kart(x, y, 420, 210, p.kapali)
     U.Etiket("Red de Trasladores", x + 22, y + 26, R.ust)
     U.Yazi(p.kapali and "Cerrada" or "Abierta", 28, 600, x + 22, y + 64, p.kapali and R.kizil or R.yesil)
     U.Paragraf(not p.var and "El sistema de Trasladores no está cargado en este servidor." or (p.kararname and "La red se cerró por decreto; no se abrirá hasta que se levante el decreto." or
          "Con la red cerrada los vendedores no entregan nuevos Trasladores. Se usa en emergencias para cortar fugas."), 12, 700, x + 22, y + 92, 376, R.ada, 18)
     if v.yonetir and p.var and not p.kararname then
          if U.Dugme(x + 22, y + 156, 376, 36, p.kapali and "Abrir red" or "Cerrar red", p.kapali and "ana" or "tehlike") then
               B.Onay(p.kapali and "Abrir red de Trasladores" or "Cerrar red de Trasladores", "Se anunciará a todos los magos.", p.kapali and "Abrir" or "Cerrar", function() B.Iste("masa.portkey", {kapali = not p.kapali}) end, not p.kapali)
          end
     end
     Ruhsatlar(x + 444, y, w - 444, h, v)
end

MASA.yaratik = function(x, y, w, h, v)
     local ply = LocalPlayer()
     local r = v.ruhemici
     local gecen = RealTime() - alinma

     U.Kart(x, y, 420, 250, #r.sevkler > 0)
     U.Etiket("Envío de Dementores", x + 22, y + 26, R.ust)
     if not r.var then
          U.Paragraf("El sistema de Dementores no está cargado en este servidor.", 12, 700, x + 22, y + 46, 376, R.soluk, 18)
     else
          U.Paragraf("El Ministro envía " .. r.adet .. " Dementores al punto al que mira durante " .. B.SureUzun(r.sure) .. ". No distinguen amigo de enemigo: quien no tenga Patronus, que no se acerque.", 12, 700, x + 22, y + 44, 376, R.ada, 18)
          local cy = y + 116
          for _, s in ipairs(r.sevkler) do
               U.Baklava(x + 30, cy + 10, 4, R.mor, 1)
               U.Yazi(U.Kisalt(s.bolge, 13, 600, 200), 13, 600, x + 44, cy + 10, R.fildisi)
               U.Yazi(B.Sure(math.max(0, s.kalan - gecen)), 13, 600, x + 300, cy + 10, R.mor, 2)
               if B.Yetkili(ply, "ruhemici") and U.Dugme(x + 312, cy - 3, 86, 26, "Retirar", "duz") then B.Iste("masa.ruhemici_geri", {sira = s.sira}) end
               cy = cy + 30
          end
          if B.Yetkili(ply, "ruhemici") then
               if U.Dugme(x + 22, y + 196, 376, 36, "Enviar donde miro · " .. B.Para(r.ucret), "tehlike", #r.sevkler >= 2) then
                    B.Onay("Envío de Dementores", "Se enviarán Dementores al punto al que miras. Se gastará " .. B.Para(r.ucret) .. " del Tesoro y se anunciará a todo el personal de servicio.", "Enviar", function()
                         B.Iste("masa.ruhemici", {})
                         B.Kapat()
                    end, true)
               end
          else
               U.Yazi("Solo el Ministro y el Subsecretario pueden dar la orden de envío.", 11, 700, x + 22, y + 220, R.soluk)
          end
     end

     OlayListesi(x, y + 270, 420, h - 270, v.olaylar, "Incidentes de criaturas", "No hay incidentes en el terreno")
     Ruhsatlar(x + 444, y, w - 444, h, v)
end

MASA.kaza = function(x, y, w, h, v)
     OlayListesi(x, y, 620, h, v.olaylar, "Daños mágicos e incidentes de memoria", "No hay daños por reparar")
     local sx, sw = x + 648, w - 648
     U.Kart(sx, y, sw, 96)
     U.Etiket("Equipo de Reversión", sx + 22, y + 26, R.ust)
     U.Paragraf("Al agente que repare in situ un incidente de daño con Reparo y cierre el informe se le abona " .. B.Para(v.odul) .. " desde el Tesoro.", 12, 700, sx + 22, y + 44, sw - 44, R.ada, 18)

     U.Bolum("Registros oficiales de Obliviate", sx, y + 126, sw)
     local ly, lh = y + 146, h - 146
     if #v.obliviate == 0 then return U.Bos(sx, ly, sw, lh, "Sin registros", "Los hechizos del Obliviator de servicio se anotan aquí.") end
     local kay = U.Kaydir("masa.obliviate", sx, ly, sw, lh, #v.obliviate * 44)
     for i, o in ipairs(v.obliviate) do
          local sy = ly + (i - 1) * 44 - kay
          if U.Gorunur(sy, 44) then
               U.Kutu(sx, sy + 43, sw - 10, 1, R.cizgi, 0.25)
               U.Yazi(U.Kisalt(o.kim_ad, 13, 600, 200), 13, 600, sx + 8, sy + 15, R.fildisi)
               U.Yazi(U.Kisalt(o.ayrinti, 11, 700, sw - 30), 11, 700, sx + 8, sy + 33, R.soluk)
               U.Yazi(B.Once(o.zaman), 11, 700, sx + sw - 20, sy + 15, R.soluk, 2)
          end
     end
     U.KaydirBitir()
end

MASA.oyun = function(x, y, w, h, v)
     Ruhsatlar(x, y, w, h, v)
end

MASA.esrar = function(x, y, w, h, v)
     local solW = 620
     U.Bolum("Salón de la Profecía", x, y + 10, solW, #v.kehanetler > 0 and "últimas " .. #v.kehanetler or nil)
     local ly, lh = y + 30, h - 30
     if #v.kehanetler == 0 then
          U.Bos(x, ly, solW, lh, "Estanterías vacías", "Cada lectura en la bola de cristal se guarda aquí como una esfera.")
     else
          local kay = U.Kaydir("masa.kehanet", x, ly, solW, lh, #v.kehanetler * 46)
          for i, k in ipairs(v.kehanetler) do
               local sy = ly + (i - 1) * 46 - kay
               if U.Gorunur(sy, 46) then
                    U.Kutu(x, sy + 45, solW - 10, 1, R.cizgi, 0.25)
                    local nefes = 0.6 + 0.4 * math.sin(U.Zaman() * 1.6 + i)
                    U.Parilti(x + 18, sy + 23, 34, R.mavi, 90 * nefes)
                    U.Disk(x + 18, sy + 23, 7, R.mavi, 0.5 + 0.3 * nefes)
                    U.Yazi(U.Kisalt(k.kisi, 14, 600, 240), 14, 600, x + 40, sy + 16, R.fildisi)
                    U.Yazi(U.Kisalt(B.Buyuk(k.burc) .. " · " .. k.kategori, 11, 700, 300), 11, 700, x + 40, sy + 34, R.soluk)
                    U.Yazi(B.Tarih(k.zaman), 11, 700, x + solW - 20, sy + 23, R.soluk, 2)
               end
          end
          U.KaydirBitir()
     end

     local sx, sw = x + solW + 28, w - solW - 28
     U.Kart(sx, y, sw, 84)
     U.Yazi(v.gizli, 30, 600, sx + 22, y + 40, R.fildisiAcik)
     U.Etiket("Expedientes abiertos sellados", sx + 22, y + 68, R.ust, 0, 9)
     if B.Yetkili(LocalPlayer(), "dosya") and U.Dugme(sx + sw - 180, y + 24, 160, 34, "Expedientes", "ikincil") then B.Git("dosya") end

     U.Bolum("Caja de pruebas · botellas de recuerdos", sx, y + 112, sw)
     local ky, kh = y + 132, h - 132
     if #v.kasa == 0 then return U.Bos(sx, ky, sw, kh, "No hay recuerdos en la caja", "Aquí se listan las Botellas de Recuerdos añadidas como prueba a los expedientes.") end
     local kay = U.Kaydir("masa.kasa", sx, ky, sw, kh, #v.kasa * 50)
     for i, a in ipairs(v.kasa) do
          local sy = ky + (i - 1) * 50 - kay
          if U.Gorunur(sy, 50) then
               local tik = U.Satir(sx, sy, sw - 10, 50)
               U.Kutu(sx, sy + 6, 2, 38, R.mavi, 0.9)
               U.Yazi(U.Kisalt(a.baslik, 14, 600, sw - 190), 14, 600, sx + 16, sy + 17, R.fildisi)
               U.Yazi(U.Kisalt("De: " .. a.sahip .. " · " .. B.SureUzun(a.sure) .. " · añadido por " .. a.ekleyen_ad, 11, 700, sw - 150), 11, 700, sx + 16, sy + 36, R.soluk)
               U.Yazi("Expediente #" .. a.dosya, 12, 600, sx + sw - 24, sy + 25, R.ust, 2)
               if tik and B.Yetkili(LocalPlayer(), "dosya") then B.Git("dosya", {id = a.dosya}) end
          end
     end
     U.KaydirBitir()
end

MASA.makam = function(x, y, w, h, v)
     local kw = (w - 24) / 2
     -- basın
     U.Kart(x, y, kw, 300)
     U.Etiket("Prensa · El Profeta", x + 22, y + 26, R.ust)
     if not v.gazete then
          U.Paragraf("El sistema de El Profeta no está cargado en este servidor.", 12, 700, x + 22, y + 46, kw - 44, R.soluk, 18)
     else
          if v.baski then
               U.Yazi("En imprenta: edición " .. v.baski.no, 18, 600, x + 22, y + 60, R.altinAcik)
               U.Yazi(U.Kisalt("“" .. v.baski.manset .. "”", 13, 700, kw - 44), 13, 700, x + 22, y + 86, R.govde)
               U.Yazi("Editor: " .. v.baski.editor, 11, 700, x + 22, y + 108, R.soluk)
          else
               U.Yazi("No hay edición en imprenta", 18, 600, x + 22, y + 60, R.ada)
               U.Yazi("Cuando el editor envíe una edición a imprenta, comienza el plazo de censura.", 12, 700, x + 22, y + 86, R.soluk)
          end
          if U.Dugme(x + 22, y + 132, kw - 44, 38, "Abrir junta de censura", "ana", not v.sansurcu, not v.sansurcu and "La censura corresponde al Ministro, Subsecretario y Viceministro." or nil) then
               B.Kapat()
               if ix.command and ix.command.Send then ix.command.Send("GazeteSansur") end
          end
          if U.Kutucuk(x + 22, y + 200, "Los decretos lleguen a la mesa de redacción como comunicado de prensa", v.bildiri, not v.yonetir) then
               B.Iste("masa.basin", {acik = not v.bildiri})
          end
          U.Paragraf("El plazo de censura puede alargarse o acortarse con un decreto (Decretos › Efecto).", 11, 700, x + 22, y + 228, kw - 44, R.soluk, 16)
     end

     -- eğitim
     local ex = x + kw + 24
     U.Kart(ex, y, kw, 300)
     U.Etiket("Inspección Educativa", ex + 22, y + 26, R.ust)
     U.Yazi(v.egitim, 30, 600, ex + 22, y + 66, R.fildisiAcik)
     U.Etiket("Decreto educativo en vigor", ex + 22, y + 96, R.soluk, 0, 9)
     U.Paragraf("Los decretos educativos vinculan a Hogwarts y se publican en los tablones del castillo. Para redactarlos, en Decretos elige el tipo «Educación».", 12, 700, ex + 22, y + 122, kw - 44, R.ada, 18)
     if U.Dugme(ex + 22, y + 240, kw - 44, 38, "Decretos", "ikincil") then B.Git("kararname") end
end

local function Ciz(x, y, w, h)
     local daireler = Dairelerim()
     if #daireler == 0 then
          return U.Bos(x, y, w, h, "No tienes acceso a ninguna mesa departamental", "Las tareas de Aplicación de la Ley Mágica están en Incidentes, Expedientes y Órdenes. Las mesas de otros departamentos son solo para su plantilla.")
     end

     local gecerli = false
     for _, d in ipairs(daireler) do
          if d.id == D.daire then gecerli = true end
     end
     if not gecerli then
          D.daire = daireler[1].id
          D.ruhsat = nil
          Iste()
     end

     local sekmeler = {}
     for i, d in ipairs(daireler) do sekmeler[i] = {id = d.id, ad = d.kisa} end
     local sec = U.Sekmeler(x, y, sekmeler, D.daire)
     if sec then
          D.daire = sec
          D.ruhsat = nil
          B.Veri["masa.durum"] = nil
          Iste()
     end

     local d = B.DaireIndex[D.daire]
     U.Yazi(d.ad, 16, 600, x, y + 62, R.fildisi)
     U.Yazi(U.Kisalt(d.aciklama, 12, 700, w - 40), 12, 700, x, y + 84, R.soluk)

     local v = B.Veri["masa.durum"]
     local gy, gh = y + 108, h - 108
     if not v or v.daire ~= D.daire then return U.Bekleniyor(x, gy, w, gh) end
     MASA[D.daire](x, gy, w, gh, v)
end

B.Sayfa("masa", {
     ad = "Mesa departamental", sira = 11, izin = "masa", kanallar = {["masa.durum"] = true, ["masa.kayitlar"] = true},
     alt = "Asuntos del departamento: registros, redes y envíos.",
     ac = function(arg)
          if arg.daire then D.daire = arg.daire end
          D.ruhsat = nil
          B.Veri["masa.durum"] = nil
          Iste()
     end,
     veri = function(anahtar) if anahtar == "masa.durum" then alinma = RealTime() end end,
     ciz = Ciz,
})
