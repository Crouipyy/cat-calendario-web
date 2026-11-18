-- "addons\\sardonbakanlik\\lua\\sardon_bakanlik\\cl_2_olay.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Expediente :: Incidentes. Canlı olay kuyruğu ve sevk: üstlen, yola çık, olay yerinde, rapor yazıp kapat.

local B = SardonBakanlik
local U = B.UI
local R = U.R

local D = {kapali = false, secili = nil}

local function Iste()
     B.Sor("olay.liste", {kapali = D.kapali})
end

local function Bul(liste, id)
     for _, o in ipairs(liste) do
          if o.id == id then return o end
     end
end

local function Ustlendim(o, ben)
     for _, a in ipairs(o.atanan or {}) do
          if a.id == ben then return true end
     end
     return false
end

local function ListeCiz(x, y, w, h, liste, ben)
     if #liste == 0 then
          return U.Bos(x, y, w, h, D.kapali and "No hay incidentes cerrados" or "Cola vacía", not D.kapali and "Robos, sinsioscopio, denuncias ciudadanas y otras notas aparecen aquí." or nil)
     end

     local satirH = 74
     local kay = U.Kaydir("olay.liste", x, y, w, h, #liste * satirH)
     for i, o in ipairs(liste) do
          local sy = y + (i - 1) * satirH - kay
          if U.Gorunur(sy, satirH) then
               local tik = U.Satir(x, sy, w - 8, satirH, D.secili == o.id)
               local renk = B.OncelikRenk[o.oncelik] or R.ada
               local nabiz = (o.oncelik >= 4 and o.durum ~= "kapali") and (0.45 + 0.55 * math.abs(math.sin(U.Zaman() * 4))) or 1
               U.Baklava(x + 20, sy + 26, 7, renk, nabiz)
               U.Yazi(U.Kisalt(o.baslik, 15, 600, w - 190), 15, 600, x + 42, sy + 22, R.fildisi)
               U.Yazi(U.Kisalt(o.bolge, 12, 700, w - 220), 12, 700, x + 42, sy + 44, R.ada)
               U.Yazi(B.Once(D.kapali and o.kapanis or o.zaman), 11, 700, x + w - 22, sy + 22, R.soluk, 2)
               U.Rozet(B.OlayDurum[o.durum] or o.durum, x + w - 22, sy + 48, B.DurumRenk[o.durum] or R.ada, false, 2)

               local tanim = B.OlayTur[o.tur]
               U.Etiket(tanim and tanim.ad or o.tur, x + 42, sy + 62, R.soluk, 0, 9)
               if #o.atanan > 0 then
                    U.Yazi(#o.atanan .. " agente" .. (Ustlendim(o, ben) and " · tú" or ""), 11, 700, x + w - 150, sy + 62, Ustlendim(o, ben) and R.yesil or R.soluk, 2)
               end
               if tik then D.secili = o.id end
          end
     end
     U.KaydirBitir()
end

local function AyrintiCiz(x, y, w, h, o, ben)
     U.Kart(x, y, w, h)
     if not o then return U.Bos(x, y, w, h, "Selecciona un incidente", "Haz clic en un incidente en la lista de la izquierda.") end

     local px, pw = x + 28, w - 56
     local tanim = B.OlayTur[o.tur] or {ad = o.tur}
     local renk = B.OncelikRenk[o.oncelik] or R.ada

     U.Etiket(tanim.ad .. "  ·  #" .. o.id, px, y + 32, R.ust)
     U.Rozet(B.OncelikAd[o.oncelik] or "", x + w - 28, y + 32, renk, o.oncelik >= 3, 2)
     for i, s in ipairs(U.Sar(o.baslik, 22, 600, pw)) do
          if i <= 2 then U.Yazi(s, 22, 600, px, y + 40 + i * 30, R.fildisiAcik) end
     end
     local cy = y + 118
     U.SusCizgi(px, cy, pw, R.altin, 0.5)

     cy = cy + 26
     cy = cy + U.Bilgi("Yer", o.bolge, px, cy, pw)
     cy = cy + U.Bilgi("Zaman", B.Tarih(o.zaman) .. "  (" .. B.Once(o.zaman) .. ")", px, cy, pw)
     if o.kaynak_ad ~= "" then cy = cy + U.Bilgi("Denunciante", o.kaynak_ad, px, cy, pw) end
     cy = cy + U.Bilgi("Durum", B.OlayDurum[o.durum] or o.durum, px, cy, pw, B.DurumRenk[o.durum])
     if o.dosya > 0 then cy = cy + U.Bilgi("Dosya", "#" .. o.dosya, px, cy, pw, R.altinAcik) end

     if o.metin ~= "" then
          cy = cy + 14
          U.Bolum("Not", px, cy, pw)
          cy = cy + 18 + U.Paragraf(o.metin, 13, 700, px, cy + 14, pw, R.govde, 20, 7) + 14
     end

     cy = cy + 14
     U.Bolum("Agentes", px, cy, pw, #o.atanan > 0 and (#o.atanan .. " persona") or nil)
     cy = cy + 22
     if #o.atanan == 0 then
          U.Yazi("Nadie lo ha asumido aún.", 13, 700, px, cy + 6, R.soluk)
          cy = cy + 26
     else
          local ax = px
          for _, a in ipairs(o.atanan) do
               local aw = U.Olc(a.ad, 12, 700) + 30
               if ax + aw > px + pw then ax, cy = px, cy + 30 end
               U.Kutu(ax, cy - 6, aw, 24, R.altin, a.id == ben and 0.2 or 0.08)
               U.Cerceve(ax, cy - 6, aw, 24, R.cizgi, 0.8)
               U.Baklava(ax + 12, cy + 6, 3, R.yesil, 1)
               U.Yazi(a.ad, 12, 700, ax + 22, cy + 6, R.fildisi)
               ax = ax + aw + 8
          end
          cy = cy + 30
     end

     if o.rapor ~= "" then
          cy = cy + 12
          U.Bolum("Rapor", px, cy, pw)
          U.Paragraf(o.rapor, 13, 700, px, cy + 32, pw, R.govde, 20, 6)
     end

     -- eylemler (altta, iki sıra: üstte durum, altta yardımcılar)
     local by = y + h - 58
     if o.durum == "kapali" then
          if o.dosya > 0 then
               if U.Dugme(px, by, 200, 38, "Archivo #" .. o.dosya .. " — abrir", "ikincil") then B.Git("dosya", {id = o.dosya}) end
          end
          return
     end

     local ust = by - 48
     local bende = Ustlendim(o, ben)
     local bx = px
     if not bende then
          if U.Dugme(bx, ust, 190, 38, "Asumir", "ana") then B.Iste("olay.ustlen", {id = o.id}) end
     else
          if o.durum ~= "yerinde" then
               if U.Dugme(bx, ust, 190, 38, "Estoy en el lugar", "ana") then B.Iste("olay.durum", {id = o.id, durum = "yerinde"}) end
               bx = bx + 200
          end
          if U.Dugme(bx, ust, 110, 38, "Abandonar", "ikincil") then B.Iste("olay.birak", {id = o.id}) end
     end

     if U.Dugme(x + w - 28 - 170, ust, 170, 38, "Cerrar con informe", "tehlike") then
          B.MetinSor("Cerrar incidente", "¿Qué ocurrió y qué se hizo? El informe queda en el registro del incidente.", "Informe breve…", function(metin) B.Iste("olay.kapat", {id = o.id, rapor = metin}) end,
               {cokSatir = true, maks = 600, enAz = 0, dugme = "Cerrar"})
     end

     bx = px
     if U.Dugme(bx, by, 190, 38, "Mostrar ruta", "ikincil", false, "La guía de campo traza la ruta hasta el lugar del incidente.") then
          B.Iste("olay.yol", {id = o.id})
          B.Kapat()
     end
     bx = bx + 200

     if o.dosya == 0 and B.Yetkili(LocalPlayer(), "dosya") then
          if U.Dugme(bx, by, 190, 38, "Abrir archivo", "ikincil", false, "Abre un expediente de investigación a partir de este incidente.") then B.Iste("dosya.ac", {olay = o.id}) end
     elseif o.dosya > 0 then
          if U.Dugme(bx, by, 190, 38, "Archivo #" .. o.dosya, "ikincil") then B.Git("dosya", {id = o.dosya}) end
     end
end

local function Ciz(x, y, w, h)
     local sec = U.Sekmeler(x, y, {{id = "acik", ad = "Abierto"}, {id = "kapali", ad = "Cerrados"}}, D.kapali and "kapali" or "acik")
     if sec then
          D.kapali = sec == "kapali"
          D.secili = nil
          U.KaydirSifirla("olay.liste")
          Iste()
     end

     local v = B.Veri["olay.liste"]
     if not v or v.kapali ~= D.kapali then return U.Bekleniyor(x, y + 40, w, h - 40) end

     if not D.secili and v.liste[1] then D.secili = v.liste[1].id end

     local gy, gh = y + 50, h - 50
     ListeCiz(x, gy, 560, gh, v.liste, v.ben)
     AyrintiCiz(x + 584, gy, w - 584, gh, D.secili and Bul(v.liste, D.secili), v.ben)
end

B.Sayfa("olay", {
     ad = "Incidentes", sira = 2, izin = "olay", rozet = "olay", kanallar = {["olay.liste"] = true},
     alt = "Todo lo que llega entre departamentos: asumir, ir, informar.",
     ac = function(arg)
          D.kapali = false
          if arg.id then D.secili = arg.id end
          Iste()
     end,
     veri = function(anahtar, tablo)
          if anahtar == "dosya.acildi" then B.Git("dosya", {id = tablo.id}) end
     end,
     ciz = Ciz,
})
