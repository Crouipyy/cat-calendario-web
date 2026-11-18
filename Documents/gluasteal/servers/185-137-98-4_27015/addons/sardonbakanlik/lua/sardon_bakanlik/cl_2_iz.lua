-- "addons\\sardonbakanlik\\lua\\sardon_bakanlik\\cl_2_iz.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Expediente :: Sala de rastros. Red de sinsioscopios, son izler, Priori Incantatem sonucu ve Tabú.

local B = SardonBakanlik
local U = B.UI
local R = U.R

local alinma = 0

local IZ_RENK = {karanlik = R.kizil, sinsioskop = R.altinAcik, tabu = R.mor, alarm = R.kizil, hafiza = R.mavi}

-- Küçük dönen topaç (Sinsioskop simgesi)
local function Topac(cx, cy, r, alarm)
     local t = U.Zaman() * (alarm and 9 or 1.4)
     local c = alarm and R.kizil or R.altin
     U.Halka(cx, cy, r, c, 0.9)
     U.Halka(cx, cy, r * 0.62, c, 0.6)
     for i = 0, 2 do
          local a = t + i * 2.094
          U.Cizgi(cx, cy, cx + math.cos(a) * r, cy + math.sin(a) * r * 0.5, c, 0.8)
     end
     U.Baklava(cx, cy, 3, R.fildisiAcik, 1)
     if alarm then U.Parilti(cx, cy, r * 4, R.kizil, 90) end
end

local function AgCiz(x, y, w, h, v)
     local ply = LocalPlayer()
     U.Bolum("Red de sinsioscopios", x, y + 10, w, #v.dedektorler .. " / " .. v.sinir.toplam)

     if U.Dugme(x, y + 30, w, 38, "Instalar sinsioscopio donde miro", "ana", not B.Yetkili(ply, "sinsioskop"), B.YetkiIpucu("sinsioskop") or
          ("Se coloca en suelo llano cercano. Por persona " .. v.sinir.kisi .. ", alcance " .. v.sinir.yaricap .. " unidades.")) then
          B.Iste("sinsioskop.kur", {})
          B.Kapat()
     end

     local ly, lh = y + 82, h - 82 - 96
     if #v.dedektorler == 0 then
          U.Bos(x, ly, w, lh, "No hay detectores en la red", "El sinsioscopio solo detecta magia oscura en su alcance.")
     else
          local kay = U.Kaydir("iz.ag", x, ly, w, lh, #v.dedektorler * 70)
          for i, d in ipairs(v.dedektorler) do
               local sy = ly + (i - 1) * 70 - kay
               if U.Gorunur(sy, 70) then
                    local ustunde = U.Icinde(x, sy, w - 10, 66)
                    U.Kutu(x, sy, w - 10, 62, R.panel, ustunde and 0.9 or 0.6)
                    U.Cerceve(x, sy, w - 10, 62, R.cizgi, 0.45)
                    local yeni = d.son > 0 and os.time() - d.son < 30
                    Topac(x + 32, sy + 31, 16, yeni)
                    U.Yazi(U.Kisalt(d.bolge, 14, 600, w - 180), 14, 600, x + 62, sy + 20, R.fildisi)
                    U.Yazi(U.Kisalt("Colocado por: " .. d.kuran .. (d.son > 0 and (" · último pitido " .. B.Once(d.son)) or " · nunca pitó"), 11, 700, w - 180), 11, 700, x + 62, sy + 42, R.soluk)
                    U.Cubuk(x + w - 100, sy + 28, 70, 4, d.can / B.Ayar.SinsioskopCan, d.can < B.Ayar.SinsioskopCan * 0.5 and R.kizil or R.yesil)
                    if ustunde and (d.kuranId == v.ben or B.Kademe(ply) >= 4) then
                         if U.Dugme(x + w - 100, sy + 36, 80, 22, "Recoger", "duz") then B.Iste("sinsioskop.topla", {ent = d.e}) end
                    end
               end
          end
          U.KaydirBitir()
     end

     local ay = y + h - 84
     U.Kutu(x, ay, w, 84, R.zeminKoyu, 0.5)
     U.Kutu(x, ay, 2, 84, R.pirinc, 0.9)
     U.Paragraf("El sinsioscopio es visible y frágil. Si el bando oscuro lo silencia, la alerta aparece aquí. Solo indica lugar y tipo de hechizo.",
          12, 700, x + 16, ay + 10, w - 32, R.ada, 18)
end

local function IzlerCiz(x, y, w, h, v)
     U.Bolum("Últimos rastros", x, y + 10, w)
     local ly, lh = y + 30, h - 30
     if #v.izler == 0 then return U.Bos(x, ly, w, lh, "Sin rastros", "Los detectores están en silencio.") end

     -- zaman çizgisi
     U.Kutu(x + 14, ly + 6, 1, math.min(lh - 12, #v.izler * 62), R.cizgi, 0.6)
     local kay = U.Kaydir("iz.izler", x, ly, w, lh, #v.izler * 62)
     for i, o in ipairs(v.izler) do
          local sy = ly + (i - 1) * 62 - kay
          if U.Gorunur(sy, 62) then
               local tik = U.Satir(x + 30, sy, w - 40, 58)
               local renk = IZ_RENK[o.tur] or R.ada
               U.Baklava(x + 14, sy + 20, 5, renk, o.durum == "kapali" and 0.45 or 1)
               U.Yazi(U.Kisalt(o.baslik, 14, 600, w - 170), 14, 600, x + 44, sy + 20, o.durum == "kapali" and R.ada or R.fildisi)
               U.Yazi(U.Kisalt(o.bolge, 11, 700, w - 170), 11, 700, x + 44, sy + 42, R.soluk)
               U.Yazi(B.Once(o.zaman), 11, 700, x + w - 20, sy + 20, R.soluk, 2)
               if o.durum ~= "kapali" then U.Rozet(B.OlayDurum[o.durum] or o.durum, x + w - 20, sy + 42, B.DurumRenk[o.durum] or R.ada, false, 2) end
               if tik then B.Git("olay", {id = o.id}) end
          end
     end
     U.KaydirBitir()
end

local function SagCiz(x, y, w, h, v)
     local ply = LocalPlayer()
     local t = v.tabu
     local gecen = RealTime() - alinma

     -- Tabú
     U.Kart(x, y, w, 250, t.etkin)
     U.Etiket("Tabú", x + 22, y + 26, R.ust)
     if t.etkin then
          local kalan = math.max(0, t.kalan - gecen)
          U.Yazi("“" .. t.kelime .. "”", 26, 600, x + 22, y + 66, R.mor)
          U.Yazi("La ubicación del hablante llega a los aurores.", 12, 700, x + 22, y + 98, R.govde)
          U.Yazi(B.Sure(kalan) .. " restante · impuesto por " .. t.koyan, 12, 700, x + 22, y + 120, R.soluk)
          U.Cubuk(x + 22, y + 142, w - 44, 4, kalan / t.sure, R.mor)
          if B.Yetkili(ply, "tabu") and U.Dugme(x + 22, y + 196, 170, 34, "Quitar tabú", "tehlike") then B.Iste("tabu.kaldir", {}) end
     else
          U.Paragraf("El ministro impone tabú a una palabra: " .. B.SureUzun(t.sure) .. " quien la pronuncie en voz alta pierde protecciones y su ubicación aparece aquí. Se anuncia a todos.",
               12, 700, x + 22, y + 44, w - 44, R.ada, 18)
          if B.Yetkili(ply, "tabu") then
               local bekleme = math.max(0, t.bekleme - gecen)
               local kelime = U.Girdi("iz.tabu", x + 22, y + 152, w - 44, 36, "Una palabra o nombre (mín. " .. B.Ayar.TabuEnAz .. " letras)", {maks = 24})
               local uygun = utf8.len(string.Trim(kelime)) >= B.Ayar.TabuEnAz and bekleme <= 0
               if U.Dugme(x + 22, y + 198, w - 44, 36, bekleme > 0 and ("Nuevo tabú en " .. B.Sure(bekleme)) or ("Imponer tabú · " .. B.Para(t.ucret)), "ana", not uygun) then
                    local k = string.Trim(kelime)
                    B.Onay("Imponer tabú", "“" .. k .. "” — se impondrá tabú. Del Tesoro " .. B.Para(t.ucret) .. " y se anuncia a todos los magos.", "Imponer tabú", function()
                         B.Iste("tabu.koy", {kelime = k})
                         U.GirdiAyarla("iz.tabu", "")
                    end, true)
               end
          else
               U.Yazi("Solo el ministro y el subsecretario pueden imponer tabú.", 12, 700, x + 22, y + 214, R.soluk)
          end
     end

     -- Priori Incantatem
     local py = y + 270
     local ph = h - 270
     U.Kart(x, py, w, ph)
     U.Etiket("Priori Incantatem", x + 22, py + 26, R.ust)
     local p = B.Veri.priori
     if not p then
          U.Paragraf("Con el sospechoso atado a tu lado, usa el menú L → «Examinar varita»: los últimos " .. B.Ayar.PrioriBoy .. " hechizos de su varita aparecen como eco fantasma. El resultado se muestra aquí y en el expediente seleccionado.",
               12, 700, x + 22, py + 46, w - 44, R.ada, 18)
          return
     end

     U.Yazi(U.Kisalt(p.ad, 17, 600, w - 150), 17, 600, x + 22, py + 56, R.fildisiAcik)
     U.Yazi(B.Once(p.zaman), 11, 700, x + w - 22, py + 56, R.soluk, 2)
     local ly, lh = py + 78, ph - 92
     if p.asa then
          U.Yazi(U.Kisalt("Asa: " .. p.asa, 11, 700, w - 44), 11, 700, x + 22, py + 76, R.soluk)
          ly, lh = ly + 16, lh - 16
     end
     if #p.liste == 0 then return U.Bos(x, ly, w, lh, "Varita en silencio", "No se ha lanzado magia recientemente.") end

     local kay = U.Kaydir("iz.priori", x + 22, ly, w - 34, lh, #p.liste * 40)
     for i, k in ipairs(p.liste) do
          local sy = ly + (i - 1) * 40 - kay
          if U.Gorunur(sy, 40) then
               local solgun = 1 - (i - 1) / math.max(1, #p.liste) * 0.55
               U.Kutu(x + 22, sy + 39, w - 56, 1, R.cizgi, 0.22)
               U.Yazi(i, 11, 600, x + 30, sy + 20, R.soluk)
               U.Yazi(U.Kisalt(k.ad, 14, 600, w - 250), 14, 600, x + 56, sy + 14, R.mor, 0, nil, solgun)
               U.Yazi(U.Kisalt(k.bolge, 10, 700, w - 250), 10, 700, x + 56, sy + 31, R.soluk)
               U.Yazi(B.SureUzun(k.once) .. " atrás", 11, 700, x + w - 40, sy + 20, R.ada, 2)
          end
     end
     U.KaydirBitir()
end

local function Ciz(x, y, w, h)
     local v = B.Veri["iz.durum"]
     if not v then return U.Bekleniyor(x, y, w, h) end

     AgCiz(x, y + 6, 400, h - 6, v)
     IzlerCiz(x + 428, y + 6, 440, h - 6, v)
     SagCiz(x + 896, y + 6, w - 896, h - 6, v)
end

B.Sayfa("iz", {
     ad = "Sala de rastros", sira = 7, izin = "iz", kanallar = {["iz.durum"] = true},
     alt = "Detectores oscuros, Priori Incantatem y tabú.",
     ac = function() B.Sor("iz.durum", {}) end,
     veri = function(anahtar) if anahtar == "iz.durum" then alinma = RealTime() end end,
     ciz = Ciz,
})
