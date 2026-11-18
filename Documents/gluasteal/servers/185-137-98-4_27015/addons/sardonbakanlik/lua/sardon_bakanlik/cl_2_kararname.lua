-- "addons\\sardonbakanlik\\lua\\sardon_bakanlik\\cl_2_kararname.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Expediente :: Decretos. En vigorki kararnameler, yeni kararname (Bakan / Subsecretario) ve Código penal.

local B = SardonBakanlik
local U = B.UI
local R = U.R

local D = {sekme = "kararname", tur = "genel", etki = "yok", deger = {tehdit = 1, sansur = 240, carpan = 100, portkey = 1}}

local TURLER = {{id = "genel", ad = "Ministerio"}, {id = "guvenlik", ad = "Seguridad"}, {id = "egitim", ad = "Educación"}}
local ETKILER = {
     {id = "yok", ad = "Solo texto", alt = "Sin efecto mecánico; se anuncia y se cuelga en tablones."},
     {id = "tehdit", ad = "Nivel de amenaza", alt = "Mantiene el nivel mínimo hasta que se derogue el decreto.", adim = 1},
     {id = "sansur", ad = "Censura de prensa", alt = "Gelecek Postası sayısı baskıdan yayına bu kadar bekler.", adim = 30},
     {id = "carpan", ad = "Multiplicador de multas", alt = "Todas las multas del código se aplican con este factor.", adim = 25},
     {id = "portkey", ad = "Cerrar red de tránsitos", alt = "Satıcılar yeni Geçit Anahtarı veremez."},
}

local function EtkiYazi(e)
     if not e or not e.tur then return nil end
     if e.tur == "tehdit" then return "Nivel de amenaza: " .. (B.Tehdit[e.deger] and B.Tehdit[e.deger].ad or "?") end
     if e.tur == "sansur" then return "Censura de prensa: " .. B.SureUzun(e.deger) end
     if e.tur == "carpan" then return "Multiplicador de multas: %" .. e.deger end
     if e.tur == "portkey" then return "Red de tránsitos cerrada" end
end

local function DegerYazi(id, d)
     if id == "tehdit" then return B.Tehdit[d].ad end
     if id == "sansur" then return B.SureUzun(d) end
     if id == "carpan" then return "%" .. d end
     return ""
end

local function ListeCiz(x, y, w, h, v)
     local ply = LocalPlayer()
     U.Bolum("En vigor", x, y + 10, w, #v.yururlukte .. " kararname")
     local ly, lh = y + 30, h - 30

     local satirlar = {}
     for _, k in ipairs(v.yururlukte) do satirlar[#satirlar + 1] = k end
     if #v.eski > 0 then satirlar[#satirlar + 1] = {ayrac = true} end
     for _, k in ipairs(v.eski) do satirlar[#satirlar + 1] = k end
     if #satirlar == 0 then return U.Bos(x, ly, w, lh, "Sin decretos", "Cuando el ministro publique el primer decreto, aparecerá aquí y en los tablones.") end

     local toplam, yukseklik = 0, {}
     for i, k in ipairs(satirlar) do
          if k.ayrac then yukseklik[i] = 40
          else yukseklik[i] = 86 + U.ParagrafH(k.metin, 12, 700, w - 60, 18, 4) + (EtkiYazi(k.etki) and 24 or 0) end
          toplam = toplam + yukseklik[i] + 10
     end

     local kay = U.Kaydir("kararname.liste", x, ly, w, lh, toplam)
     local sy = ly - kay
     for i, k in ipairs(satirlar) do
          local kh = yukseklik[i]
          if U.Gorunur(sy, kh) then
               if k.ayrac then
                    U.Bolum("Derogados", x, sy + 24, w - 14)
               else
                    local etkin = k.durum == "yururlukte"
                    U.Kart(x, sy, w - 14, kh, false, etkin and 1 or 0.6)
                    U.Etiket((B.DecretoTurAd[k.tur] or "Decreto") .. " No. " .. k.no, x + 20, sy + 24, etkin and R.ust or R.soluk)
                    U.Yazi(U.Kisalt(k.baslik, 17, 600, w - 200), 17, 600, x + 20, sy + 50, etkin and R.fildisiAcik or R.ada)
                    local ph = U.Paragraf(k.metin, 12, 700, x + 20, sy + 68, w - 60, etkin and R.govde or R.soluk, 18, 4)
                    local ey = sy + 74 + ph
                    local etki = EtkiYazi(k.etki)
                    if etki then
                         U.Baklava(x + 26, ey + 6, 4, R.altinAcik, etkin and 1 or 0.5)
                         U.Yazi(etki, 12, 600, x + 40, ey + 6, etkin and R.altinAcik or R.soluk)
                    end
                    U.Yazi("— " .. k.yazan_ad .. " · " .. B.Tarih(k.zaman), 11, 700, x + w - 34, sy + 24, R.soluk, 2)
                    if etkin and B.Yetkili(ply, "kararname") and U.Icinde(x, sy, w - 14, kh) then
                         if U.Dugme(x + w - 164, sy + 38, 130, 26, "Derogar", "tehlike") then
                              B.Onay("Derogar decreto", "El n.º " .. k.no .. " dejará de vigorar; cesará su efecto si lo tenía.", "Retirar", function() B.Iste("kararname.kaldir", {id = k.id}) end, true)
                         end
                    end
               end
          end
          sy = sy + kh + 10
     end
     U.KaydirBitir()
end

local function YazCiz(x, y, w, h, v)
     local ply = LocalPlayer()
     U.Kart(x, y, w, h, true)
     local px, pw = x + 24, w - 48

     if not B.Yetkili(ply, "kararname") then
          U.Resim(B.Doku("muhur"), x + w / 2 - 70, y + 70, 140, 140, R.beyaz, 0.5)
          U.Yazi("Despacho de decretos", 17, 600, x + w / 2, y + 250, R.fildisi, 1)
          for i, s in ipairs(U.Sar("Solo el ministro y el subsecretario redactan decretos. Los vigentes obligan a todos y cuelgan en los tablones.", 12, 700, pw - 20)) do
               U.Yazi(s, 12, 700, x + w / 2, y + 266 + i * 19, R.ada, 1)
          end
          return
     end

     U.Etiket("Nuevo decreto", px, y + 28, R.ust)

     -- tür
     local bw = (pw - 2 * 8) / 3
     for i, t in ipairs(TURLER) do
          local bx = px + (i - 1) * (bw + 8)
          local sec = D.tur == t.id
          local ustunde = U.Icinde(bx, y + 46, bw, 32)
          U.Kutu(bx, y + 46, bw, 32, R.altin, sec and 0.24 or (ustunde and 0.1 or 0.03))
          U.Cerceve(bx, y + 46, bw, 32, sec and R.altinAcik or R.cizgi, 0.85)
          U.Yazi(B.Buyuk(t.ad), 10, 600, bx + bw / 2, y + 62, sec and R.fildisiAcik or R.ada, 1, 1.3)
          if ustunde then
               U.imlec = true
               if U.Tik(bx, y + 46, bw, 32) then D.tur = t.id end
          end
     end

     local baslik = U.Girdi("kararname.baslik", px, y + 92, pw, 36, "Título del decreto", {maks = 80})
     local metin = U.Girdi("kararname.metin", px, y + 138, pw, 190, "Texto del decreto…", {cokSatir = true, maks = 1200})

     -- etki
     local ey = y + 346
     U.Etiket("Etki", px, ey, R.soluk, 0, 10)
     ey = ey + 14
     for _, e in ipairs(ETKILER) do
          local sec = D.etki == e.id
          if U.Kutucuk(px, ey + 12, e.ad, sec) then D.etki = e.id end
          if sec and e.adim then
               local sinir = v.etkiler[e.id]
               D.deger[e.id] = U.Adim(px + pw - 178, ey - 3, D.deger[e.id], sinir.en, sinir.ust, e.adim, DegerYazi(e.id, D.deger[e.id]))
          end
          ey = ey + 30
     end
     for _, e in ipairs(ETKILER) do
          if e.id == D.etki then U.Paragraf(e.alt, 11, 700, px, ey + 2, pw, R.soluk, 16) end
     end

     local hazir = #string.Trim(baslik) >= 4 and #string.Trim(metin) >= 10
     if U.Dugme(px, y + h - 62, pw, 42, "Sellar y publicar", "ana", not hazir) then
          B.Onay("Publicar decreto", "Decreto numaralanıp bütün büyücülere duyurulacak, panolara asılacak ve Gelecek Postası'na bildiri olarak gidecek.", "Publicar", function()
               B.Iste("kararname.yaz", {baslik = baslik, metin = metin, tur = D.tur, etki = D.etki ~= "yok" and {tur = D.etki, deger = D.deger[D.etki]} or nil})
               U.MuhurBas(x + w / 2, y + 230)
               U.GirdiAyarla("kararname.baslik", "")
               U.GirdiAyarla("kararname.metin", "")
               D.etki = "yok"
          end)
     end
end

local function KanunCiz(x, y, w, h)
     local ply = LocalPlayer()
     local yetkili = B.Yetkili(ply, "kanun")
     local carpan = GetGlobalFloat("SBCezaCarpani", 1)

     U.Yazi("Multas " .. (carpan ~= 1 and ("por decreto %" .. math.Round(carpan * 100) .. " en vigor. ") or "") ..
          (yetkili and "Puedes pulsar un artículo y cambiar multa y prisión." or "Solo el ministro y el subsecretario pueden cambiar los valores."), 12, 700, x, y + 12, R.ada)

     local satirlar = {}
     for _, b in ipairs(B.KanunBolumleri) do
          satirlar[#satirlar + 1] = {baslik = b.ad}
          for _, m in ipairs(B.Kanun) do
               if m.bolum == b.id then satirlar[#satirlar + 1] = {m = m} end
          end
     end

     local ly, lh = y + 34, h - 34
     local toplam = 0
     for _, s in ipairs(satirlar) do toplam = toplam + (s.baslik and 38 or 48) end

     local kay = U.Kaydir("kararname.kanun", x, ly, w, lh, toplam)
     local sy = ly - kay
     for _, s in ipairs(satirlar) do
          if s.baslik then
               if U.Gorunur(sy, 38) then U.Bolum(s.baslik, x, sy + 22, w - 14) end
               sy = sy + 38
          else
               local m = s.m
               if U.Gorunur(sy, 48) then
                    local tik = false
                    if yetkili then tik = U.Satir(x, sy, w - 14, 48) else U.Kutu(x, sy + 47, w - 14, 1, R.cizgi, 0.25) end
                    U.Yazi(m.kod, 11, 600, x + 10, sy + 24, R.ust, 0, 1.2)
                    U.Yazi(U.Kisalt(m.ad, 14, 600, 380), 14, 600, x + 70, sy + 16, R.fildisi)
                    U.Yazi(U.Kisalt(m.aciklama, 11, 700, 640), 11, 700, x + 70, sy + 34, R.soluk)
                    U.Yazi(m.para > 0 and B.Para(m.para) or "—", 14, 600, x + w - 260, sy + 24, R.altinAcik, 2)
                    U.Yazi(m.hapis > 0 and B.SureUzun(m.hapis) or "—", 14, 600, x + w - 100, sy + 24, m.agir >= 3 and R.kizil or R.fildisi, 2)
                    if m.degisti then U.Rozet("Modificado", x + w - 34, sy + 24, R.mor, false, 2) end

                    if tik then
                         local para, hapis = m.para, m.hapis
                         B.Kip({baslik = m.kod .. "  " .. m.ad, w = 520, ciz = function(kx, ky, kw)
                              local ph = U.Paragraf(m.aciklama, 12, 700, kx, ky, kw, R.ada, 18)
                              local cy = ky + ph + 18
                              U.Etiket("Multa", kx, cy, R.soluk, 0, 10)
                              para = U.Adim(kx, cy + 12, para, 0, B.Ayar.CezaAzami, 5, B.Para(para))
                              U.Etiket("Azkaban", kx + 250, cy, R.soluk, 0, 10)
                              hapis = U.Adim(kx + 250, cy + 12, hapis, 0, B.Ayar.AzamiHapis, 30, hapis > 0 and B.SureUzun(hapis) or "yok")
                              cy = cy + 70
                              if U.Dugme(kx + kw - 150, cy, 150, 38, "Guardar", "ana") then
                                   B.Iste("kanun.duzenle", {kod = m.kod, para = para, hapis = hapis})
                                   B.KipKapat()
                              end
                              if U.Dugme(kx + kw - 290, cy, 130, 38, "Cancelar", "ikincil") then B.KipKapat() end
                              if m.degisti and U.Dugme(kx, cy, 150, 38, "Predeterminado", "duz") then
                                   B.Iste("kanun.duzenle", {kod = m.kod, sifirla = true})
                                   B.KipKapat()
                              end
                              return cy + 38 - ky
                         end})
                    end
               end
               sy = sy + 48
          end
     end
     U.KaydirBitir()
end

local function Ciz(x, y, w, h)
     local sec = U.Sekmeler(x, y, {{id = "kararname", ad = "Decretos"}, {id = "kanun", ad = "Código penal"}}, D.sekme)
     if sec then D.sekme = sec end

     if D.sekme == "kanun" then return KanunCiz(x, y + 46, w, h - 46) end

     local v = B.Veri["kararname.liste"]
     if not v then return U.Bekleniyor(x, y + 46, w, h - 46) end
     ListeCiz(x, y + 50, 800, h - 50, v)
     YazCiz(x + 826, y + 50, w - 826, h - 50, v)
end

B.Sayfa("kararname", {
     ad = "Decretos", sira = 9, izin = "kararname_oku", kanallar = {["kararname.liste"] = true},
     alt = "Palabra del Ministerio: decretos y código penal.",
     ac = function() B.Sor("kararname.liste", {}) end,
     ciz = Ciz,
})
