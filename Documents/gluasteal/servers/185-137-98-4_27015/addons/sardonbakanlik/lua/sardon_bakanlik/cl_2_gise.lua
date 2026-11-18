-- "addons\\sardonbakanlik\\lua\\sardon_bakanlik\\cl_2_gise.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sicil Defteri :: Vatandaş Gişesi. Bakanlık üyesi olmayanlar aynı tuşla bunu görür:
-- borç ödeme, aranıyor listesi, yürürlükteki kararnameler, ihbar ve dilekçe.

local B = SardonBakanlik
local U = B.UI
local R = U.R

local alinma = 0
local tur = "ihbar"

local function Ciz(x, y, w, h)
     local v = B.Veri.gise
     if not v then return U.Bekleniyor(x, y, w, h) end
     local gecen = RealTime() - alinma

     local solW = 600
     -- uyarılar
     local cy = y + 6

     -- kimlik belgesi ve nüfus kaydı (cl_2_kimlik.lua)
     if B.Sayfalar.kimlik then
          U.Kart(x, cy, solW, 54)
          U.Baklava(x + 22, cy + 27, 5, R.altinAcik, 1)
          U.Yazi("Documento de identidad y registro civil", 15, 600, x + 40, cy + 19, R.fildisiAcik)
          U.Yazi("Denuncia la pérdida, solicita un duplicado o renueva la fotografía.", 12, 700, x + 40, cy + 38, R.soluk)
          if U.Dugme(x + solW - 182, cy + 9, 168, 36, "Trámites de identidad", "ikincil") then B.Git("kimlik") end
          cy = cy + 66
     end
     if v.araniyorum then
          U.Kutu(x, cy, solW, 54, R.kizil, 0.16)
          U.Cerceve(x, cy, solW, 54, R.kizil, 0.9)
          U.Yazi("El Ministerio te busca.", 16, 600, x + 20, cy + 18, R.kizil)
          U.Yazi("Para entregarte, acude a un Auror o al Ministerio de Magia.", 12, 700, x + 20, cy + 38, R.govde)
          cy = cy + 66
     end
     if v.men > 0 then
          U.Kutu(x, cy, solW, 44, R.mor, 0.14)
          U.Cerceve(x, cy, solW, 44, R.mor, 0.8)
          U.Yazi("Silencio de varita: " .. B.SureUzun(math.max(0, v.men - gecen)) .. " más sin poder lanzar hechizos.", 14, 600, x + 20, cy + 22, R.mor)
          cy = cy + 56
     end

     -- borçlar
     U.Bolum("Tus deudas", x, cy + 10, solW)
     cy = cy + 30
     if #v.borclar == 0 then
          U.Yazi("No debes nada al Ministerio.", 13, 700, x, cy + 10, R.soluk)
          cy = cy + 36
     end
     for _, b in ipairs(v.borclar) do
          local gecik = b.durum == "gecikti"
          U.Kart(x, cy, solW, 70, gecik)
          U.Yazi(U.Kisalt(b.baslik, 14, 600, solW - 250), 14, 600, x + 20, cy + 24, R.fildisi)
          U.Yazi(b.yazan_ad .. " · " .. B.Tarih(b.zaman) .. (gecik and " · VENCIDO" or (" · vence " .. B.Once(os.time() - (b.bitis - os.time())):gsub(" önce", " después"))), 11, 700, x + 20, cy + 48, gecik and R.kizil or R.soluk)
          U.Yazi(B.Para(b.deger), 18, 600, x + solW - 140, cy + 35, R.altinAcik, 2)
          if U.Dugme(x + solW - 122, cy + 18, 104, 34, "Pagar", "ana") then B.Iste("ceza.ode", {id = b.id}) end
          cy = cy + 80
     end

     -- ruhsatlar
     if #v.ruhsatlar > 0 then
          cy = cy + 10
          U.Bolum("Registros y licencias", x, cy + 10, solW)
          cy = cy + 30
          local rx = x
          for _, r in ipairs(v.ruhsatlar) do
               local t = B.RuhsatIndex[r.baslik]
               rx = rx + U.Rozet(t and t.ad or r.baslik, rx, cy + 10, R.yesil) + 8
          end
          cy = cy + 30
     end

     -- ihbar / dilekçe
     cy = cy + 14
     U.Bolum("Denuncia y solicitud", x, cy + 10, solW)
     cy = cy + 30
     local s = U.Sekmeler(x, cy, {{id = "ihbar", ad = "Denuncia a los Aurores"}, {id = "dilekce", ad = "Solicitud a la Oficina"}}, tur)
     if s then tur = s end
     cy = cy + 44
     local kutuH = math.Clamp(y + h - cy - 60, 70, 180)
     local metin = U.Girdi("gise.metin", x, cy, solW, kutuH, tur == "ihbar" and "¿Qué has visto? Tu ubicación se añadirá a la denuncia." or "¿Qué quieres transmitir a la Oficina del Ministro?",
          {cokSatir = true, maks = B.Ayar.IhbarMaks})
     local bekle = math.max(0, v.ihbarBekleme - gecen)
     if U.Dugme(x + solW - 200, cy + kutuH + 12, 200, 38, bekle > 0 and ("El lechuzo vuelve · " .. math.ceil(bekle)) or "Enviar con lechuzo", "ana", bekle > 0 or #string.Trim(metin) < 8) then
          B.Iste("ihbar", {metin = metin, tur = tur})
          U.GirdiAyarla("gise.metin", "")
          v.ihbarBekleme = B.Ayar.IhbarBekleme + gecen
     end

     -- sağ: aranıyor + kararnameler
     local sx, sw = x + solW + 28, w - solW - 28
     U.Bolum("Buscados", sx, y + 16, sw)
     local ay = y + 36
     if #v.aranan == 0 then
          U.Yazi("No hay nadie buscado.", 13, 700, sx, ay + 12, R.soluk)
          ay = ay + 40
     end
     local kw = (sw - 2 * 14) / 3
     for i, a in ipairs(v.aranan) do
          if i <= 3 then
               local kx = sx + (i - 1) * (kw + 14)
               U.Kutu(kx, ay, kw, 200, R.zeminKoyu, 0.6)
               U.Cerceve(kx, ay, kw, 200, R.kizil, 0.7)
               U.Yazi("BUSCADO", 15, 600, kx + kw / 2, ay + 22, R.kizil, 1, 3)
               U.Model("gise.afis" .. i, kx + 14, ay + 38, kw - 28, 96, a.model, a.ogr)
               U.Yazi(U.Kisalt(a.ad, 14, 600, kw - 20), 14, 600, kx + kw / 2, ay + 150, R.fildisiAcik, 1)
               U.Yazi(a.odul > 0 and ("Recompensa " .. B.Para(a.odul)) or "Sin recompensa", 12, 600, kx + kw / 2, ay + 174, R.altinAcik, 1)
               if U.Icinde(kx, ay, kw, 200) then U.ipucu = a.gerekce end
          end
     end
     if #v.aranan > 0 then ay = ay + 214 end

     U.Bolum("Decretos en vigor", sx, ay + 10, sw)
     local ly, lh = ay + 30, y + h - ay - 30
     if #v.kararnameler == 0 then return U.Bos(sx, ly, sw, lh, "No hay decretos en vigor") end
     local toplam = 0
     for _, k in ipairs(v.kararnameler) do toplam = toplam + 70 + U.ParagrafH(k.metin, 12, 700, sw - 50, 18, 3) end
     local kay = U.Kaydir("gise.kararname", sx, ly, sw, lh, toplam)
     local sy = ly - kay
     for _, k in ipairs(v.kararnameler) do
          local kh = 60 + U.ParagrafH(k.metin, 12, 700, sw - 50, 18, 3)
          if U.Gorunur(sy, kh) then
               U.Kart(sx, sy, sw - 12, kh)
               U.Etiket((B.KararnameTurAd[k.tur] or "Decreto") .. " N.º " .. k.no, sx + 18, sy + 20, R.ust, 0, 9)
               U.Yazi(U.Kisalt(k.baslik, 15, 600, sw - 60), 15, 600, sx + 18, sy + 42, R.fildisiAcik)
               U.Paragraf(k.metin, 12, 700, sx + 18, sy + 56, sw - 50, R.govde, 18, 3)
          end
          sy = sy + kh + 10
     end
     U.KaydirBitir()
end

B.Sayfa("gise", {
     ad = "Ventanilla del ciudadano", gizli = true,
     alt = function()
          local v = B.Veri.gise
          return v and ("Bienvenido, " .. v.ad .. ". Nivel de amenaza: " .. (B.Tehdit[v.tehdit] or B.Tehdit[0]).ad .. ".") or ""
     end,
     ac = function() B.Sor("gise", {}) end,
     veri = function(anahtar) if anahtar == "gise" then alinma = RealTime() end end,
     ciz = Ciz,
})