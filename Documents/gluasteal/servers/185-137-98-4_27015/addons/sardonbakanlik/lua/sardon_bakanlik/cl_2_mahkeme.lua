-- "addons\\sardonbakanlik\\lua\\sardon_bakanlik\\cl_2_mahkeme.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Expediente :: Wizengamot. Vista sırası, süren duruşma (delil sunma, oylama, hüküm), eski hükümler.

local B = SardonBakanlik
local U = B.UI
local R = U.R

local alinma = 0
local hukum = {hapis = 0, para = 0, men = 0, dosya = nil}

local ASAMA = {acik = "Vista en curso", oylama = "Oylama", hukum = "Sentencia pendiente"}

local function SiraCiz(x, y, w, h, v)
     U.Bolum("Expedientes en espera de vista", x, y + 10, w, #v.bekleyen > 0 and (#v.bekleyen .. " dosya") or nil)
     local ly = y + 30
     if #v.bekleyen == 0 then
          U.Bos(x, ly, w, 220, "No hay expedientes en cola", "Bir dosya \"Remitir al Wizengamot\" ile buraya düşer.")
     end
     for i, d in ipairs(v.bekleyen) do
          if i <= 6 then
               local sy = ly + (i - 1) * 78
               U.Kart(x, sy, w, 70)
               U.Yazi("#" .. d.id, 13, 600, x + 20, sy + 24, R.ust)
               U.Yazi(U.Kisalt(d.baslik, 16, 600, w - 330), 16, 600, x + 70, sy + 24, R.fildisiAcik)
               U.Yazi(U.Kisalt("Acusado: " .. d.saniklar .. "  ·  Fiscal: " .. d.sorumlu_ad, 12, 700, w - 330), 12, 700, x + 70, sy + 48, R.ada)
               if U.Dugme(x + w - 220, sy + 16, 200, 38, "Abrir vista", "ana", not v.acabilir or v.durusma ~= nil,
                    v.durusma and "No se abre otra vista hasta que termine la actual." or (not v.acabilir and "Un superior de 4.ª categoría abre la vista." or "Serás presidente; quien esté a tu alrededor cuenta como presente.")) then
                    B.Onay("Convocar el Wizengamot", "Archivo #" .. d.id .. " — se abrirá la vista. Serás presidente; " .. B.Ayar.MahkemeYaricap ..
                         " unidades alrededor cuentan en sala. Citación al acusado.", "Abrir vista", function() B.Iste("mahkeme.ac", {dosya = d.id}) end)
               end
          end
     end
end

local function GecmisCiz(x, y, w, h, v)
     U.Bolum("Últimas sentencias", x, y + 10, w)
     local ly, lh = y + 30, h - 30
     if #v.gecmis == 0 then return U.Bos(x, ly, w, lh, "Aún no hay sentencias") end
     local kay = U.Kaydir("mahkeme.gecmis", x, ly, w, lh, #v.gecmis * 62)
     for i, g in ipairs(v.gecmis) do
          local sy = ly + (i - 1) * 62 - kay
          if U.Gorunur(sy, 62) then
               local tik = U.Satir(x, sy, w - 10, 58)
               local absolución = string.sub(g.hukum, 1, 6) == "Absolución"
               U.Baklava(x + 14, sy + 20, 5, absolución and R.yesil or (string.sub(g.hukum, 1, 5) == "Culpable" and R.kizil or R.soluk), 1)
               U.Yazi(U.Kisalt("#" .. g.dosya .. "  " .. (g.baslik or ""), 14, 600, w - 150), 14, 600, x + 32, sy + 20, R.fildisi)
               U.Yazi(U.Kisalt(g.hukum, 11, 700, w - 60), 11, 700, x + 32, sy + 42, R.ada)
               U.Yazi(B.Once(g.kapanis), 11, 700, x + w - 24, sy + 20, R.soluk, 2)
               if tik and B.Yetkili(LocalPlayer(), "dosya") then B.Git("dosya", {id = g.dosya}) end
          end
     end
     U.KaydirBitir()
end

local function DurusmaCiz(x, y, w, h, v)
     local d = v.durusma
     local gecen = RealTime() - alinma

     -- başlık kartı
     U.Kart(x, y, w, 118, true)
     U.Resim(B.Doku("muhur"), x + w - 124, y + 8, 100, 100, R.beyaz, 0.14)
     U.Etiket("Wizengamot convocado  ·  Archivo #" .. d.dosya, x + 24, y + 26, R.ust)
     U.Yazi(U.Kisalt(d.baslik, 22, 600, w - 420), 22, 600, x + 24, y + 58, R.fildisiAcik)
     U.Rozet(ASAMA[d.asama] or d.asama, x + 24, y + 92, d.asama == "oylama" and R.mor or R.altinAcik, true)
     U.Yazi("Presidente " .. d.baskan_ad .. "   ·   Fiscal " .. d.savci_ad .. "   ·   Defensa " .. (d.savunma_ad ~= "" and d.savunma_ad or "el propio acusado") ..
          "   ·   en sala " .. d.salon .. " persona", 12, 700, x + 24 + 190, y + 92, R.ada)

     local gy = y + 136
     local gh = h - 136
     local solW = 420
     local ortaX, ortaW = x + solW + 24, 430
     local sagX = ortaX + ortaW + 24
     local sagW = w - (sagX - x)

     -- sol: sanıklar + heyet
     U.Bolum("Acusados", x, gy + 10, solW)
     local cy = gy + 30
     for _, s in ipairs(d.saniklar) do
          U.Kutu(x, cy + 35, solW, 1, R.cizgi, 0.25)
          U.Baklava(x + 10, cy + 18, 4, R.kizil, 1)
          U.Yazi(U.Kisalt(s.ad, 14, 600, solW - 170), 14, 600, x + 26, cy + 18, R.fildisi)
          U.Rozet(s.salonda and "En sala" or "En ausencia", x + solW, cy + 18, s.salonda and R.yesil or R.soluk, false, 2)
          cy = cy + 36
     end
     if d.benBaskan and d.asama == "acik" then
          cy = cy + 6
          if U.Dugme(x, cy, 200, 28, "Asignar defensa", "duz") then
               B.KisiSec("Quien asumirá la defensa", function(id) B.Iste("mahkeme.savunma", {kisi = id}) end, "La persona debe estar en sala.")
          end
          cy = cy + 30
     end

     cy = cy + 16
     U.Bolum("Tribunal", x, cy + 10, solW, #d.heyet .. " oy")
     cy = cy + 30
     for _, hy in ipairs(d.heyet) do
          U.Kutu(x, cy + 33, solW, 1, R.cizgi, 0.22)
          if hy.oy then U.Baklava(x + 10, cy + 17, 5, R.altinAcik, 1) else U.BaklavaCizgi(x + 10, cy + 17, 5, R.pirinc, 0.8) end
          U.Yazi(U.Kisalt(hy.ad, 13, 600, solW - 150), 13, 600, x + 26, cy + 17, R.fildisi)
          if hy.id == d.baskan then U.Etiket("Presidente", x + solW, cy + 17, R.ust, 2, 9)
          elseif d.asama ~= "acik" then U.Yazi(hy.oy and "oyunu verdi" or "bekleniyor", 11, 700, x + solW, cy + 17, hy.oy and R.yesil or R.soluk, 2) end
          cy = cy + 34
     end

     -- orta: deliller
     U.Bolum("Pruebas", ortaX, gy + 10, ortaW, d.sunulan > 0 and (d.sunulan .. " kez sunuldu") or nil)
     local ly, lh = gy + 30, gh - 30
     if #d.deliller == 0 then
          U.Bos(ortaX, ly, ortaW, lh, "No hay pruebas en el archivo")
     else
          local kay = U.Kaydir("mahkeme.delil", ortaX, ly, ortaW, lh, #d.deliller * 58)
          for i, e in ipairs(d.deliller) do
               local sy = ly + (i - 1) * 58 - kay
               if U.Gorunur(sy, 58) then
                    U.Kutu(ortaX, sy, ortaW - 10, 50, R.zeminKoyu, 0.5)
                    U.Kutu(ortaX, sy, 2, 50, e.tur == "ani" and R.mavi or R.pirinc, 0.9)
                    U.Etiket(B.DelilTurAd[e.tur] or e.tur, ortaX + 14, sy + 16, R.ust, 0, 9)
                    U.Yazi(U.Kisalt(e.baslik, 13, 600, ortaW - 170), 13, 600, ortaX + 14, sy + 35, R.fildisi)
                    if d.benBaskan and d.asama == "acik" then
                         if U.Dugme(ortaX + ortaW - 130, sy + 10, 108, 30, e.tur == "ani" and "Proyectar" or "Presentar", "ikincil", false,
                              e.tur == "ani" and "Todos en sala entran en el recuerdo; tú controlas la reproducción." or "La prueba se muestra a todos en sala.") then
                              B.Iste("mahkeme.delil", {id = e.id})
                              if e.tur == "ani" then B.Kapat() end
                         end
                    end
               end
          end
          U.KaydirBitir()
     end

     -- sağ: aşamaya göre
     U.Kart(sagX, gy, sagW, gh)
     local px, pw = sagX + 22, sagW - 44
     if d.asama == "acik" then
          U.Etiket("Vista", px, gy + 26, R.ust)
          U.Paragraf("El fiscal expone la acusación y la defensa responde. El presidente presenta pruebas; cuando baste, inicia la votación.", 12, 700, px, gy + 44, pw, R.ada, 18)
          U.Yazi("Total del código penal", 11, 700, px, gy + 138, R.soluk)
          U.Yazi((d.para > 0 and B.Para(d.para) or "") .. ((d.para > 0 and d.hapis > 0) and "  ·  " or "") .. (d.hapis > 0 and (B.SureUzun(d.hapis) .. " Azkaban") or ""), 15, 600, px, gy + 160, R.fildisi)
          if d.benBaskan then
               if U.Dugme(px, gy + gh - 104, pw, 40, "Iniciar votación", "ana") then B.Iste("mahkeme.oylama", {}) end
               if U.Dugme(px, gy + gh - 56, pw, 34, "Aplazar vista", "tehlike") then
                    B.Onay("Aplazar vista", "El Wizengamot se disolverá sin sentencia; el expediente sigue en cola.", "Aplazar", function() B.Iste("mahkeme.ertele", {}) end, true)
               end
          end
     elseif d.asama == "oylama" then
          local kalan = math.max(0, d.oylamaRestante - gecen)
          U.Etiket("Oylama", px, gy + 26, R.mor)
          U.Yazi(B.Sure(kalan), 44, 600, px, gy + 76, R.fildisiAcik)
          U.Cubuk(px, gy + 112, pw, 4, kalan / B.Ayar.OylamaSure, R.mor)
          if d.benTribunal then
               if d.oyum == nil then
                    U.Yazi("Oyunu kullan:", 13, 700, px, gy + 150, R.govde)
                    if U.Dugme(px, gy + 172, pw, 46, "Culpable", "tehlike") then B.Iste("mahkeme.oy", {suclu = true}) end
                    if U.Dugme(px, gy + 228, pw, 46, "Absolución", "ana") then B.Iste("mahkeme.oy", {suclu = false}) end
               else
                    U.Yazi("Oyun: " .. (d.oyum and "culpable" or "absolución"), 15, 600, px, gy + 160, d.oyum and R.kizil or R.yesil)
                    U.Yazi("Esperando al resto de miembros.", 12, 700, px, gy + 186, R.soluk)
               end
          else
               U.Paragraf("Tribunal oyluyor. Oy hakkı salondaki, mesaideki 3. kademe ve üstü agentelerde.", 12, 700, px, gy + 140, pw, R.ada, 18)
          end
     elseif d.asama == "hukum" then
          U.Etiket("Karar: culpable", px, gy + 26, R.kizil)
          if not d.benBaskan then
               U.Paragraf("El presidente redacta la sentencia.", 13, 700, px, gy + 50, pw, R.ada, 20)
          else
               if hukum.dosya ~= d.dosya then hukum = {hapis = d.hapis, para = d.para, men = 0, kir = false, dosya = d.dosya} end
               U.Yazi("La sentencia no puede superar el total del código penal.", 12, 700, px, gy + 52, R.soluk)

               U.Etiket("Azkaban", px, gy + 88, R.soluk, 0, 10)
               hukum.hapis = U.Adim(px, gy + 100, hukum.hapis, 0, d.hapis, 60, hukum.hapis > 0 and B.SureUzun(hukum.hapis) or "yok")
               U.Yazi("como máximo " .. B.SureUzun(d.hapis), 11, 700, px + 190, gy + 115, R.soluk)

               U.Etiket("Multa", px, gy + 152, R.soluk, 0, 10)
               hukum.para = U.Adim(px, gy + 164, hukum.para, 0, d.para, 50, B.Para(hukum.para))
               U.Yazi("como máximo " .. B.Para(d.para), 11, 700, px + 190, gy + 179, R.soluk)

               U.Etiket("Prohibición de varita", px, gy + 216, R.soluk, 0, 10)
               hukum.men = U.Adim(px, gy + 228, hukum.men, 0, v.sinir.men, 300, hukum.men > 0 and B.SureUzun(hukum.men) or "yok")
               U.Yazi("no puede usar magia", 11, 700, px + 190, gy + 243, R.soluk)

               if SardonOli then
                    if U.Kutucuk(px, gy + 286, "Asasını kır (varita registrada en Ollivanders)", hukum.kir) then hukum.kir = not hukum.kir end
               end

               local bos = hukum.hapis == 0 and hukum.para == 0 and hukum.men == 0 and not hukum.kir
               if U.Dugme(px, gy + gh - 60, pw, 42, "Sellar sentencia", "ana", bos) then
                    B.Onay("Sellar sentencia", "La sentencia se inscribirá en el expediente de los acusados y se ejecutará al instante. Orden de detención para acusados ausentes.", "Sellar", function()
                         B.Iste("mahkeme.hukum", {hapis = hukum.hapis, para = hukum.para, men = hukum.men, kir = hukum.kir == true})
                         U.MuhurBas(sagX + sagW / 2, gy + gh - 150)
                    end, true)
               end
          end
     end
end

local function Ciz(x, y, w, h)
     local v = B.Veri["mahkeme.liste"]
     if not v then return U.Bekleniyor(x, y, w, h) end

     if v.durusma then
          DurusmaCiz(x, y + 6, w, h - 6, v)
     else
          SiraCiz(x, y + 6, 760, h - 6, v)
          GecmisCiz(x + 788, y + 6, w - 788, h - 6, v)
     end
end

B.Sayfa("mahkeme", {
     ad = "Wizengamot", sira = 8, izin = "mahkeme", kanallar = {["mahkeme.liste"] = true},
     alt = "Alto tribunal de magos: prueba, votación, sentencia.",
     ac = function() B.Sor("mahkeme.liste", {}) end,
     veri = function(anahtar) if anahtar == "mahkeme.liste" then alinma = RealTime() end end,
     ciz = Ciz,
})
