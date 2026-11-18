-- "addons\\sardonbakanlik\\lua\\sardon_bakanlik\\cl_2_kumanda.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sicil Defteri :: Kumanda. Günün özeti: sayılar, açık olaylar, mesaideki kadro, tehdit seviyesi.

local B = SardonBakanlik
local U = B.UI
local R = U.R

local KUTULAR = {
     {anahtar = "olay", ad = "Incidente abierto", sayfa = "olay"},
     {anahtar = "dosya", ad = "Expediente abierto", sayfa = "dosya"},
     {anahtar = "aranan", ad = "Buscados", sayfa = "emir"},
     {anahtar = "tutuklu", ad = "En Azkaban", sayfa = "azkaban"},
     {anahtar = "onay", ad = "Pendiente de confirmar", sayfa = "emir"},
     {anahtar = "dedektor", ad = "Sinsioskop", sayfa = "iz"},
}

local function SayiKutusu(x, y, w, h, k, deger)
     local sayfa = B.Sayfalar[k.sayfa]
     local acik = sayfa and (not sayfa.izin or B.Yetkili(LocalPlayer(), sayfa.izin))
     local ustunde = acik and U.Icinde(x, y, w, h)

     U.Kart(x, y, w, h, ustunde)
     U.Yazi(deger, 38, 600, x + 22, y + 46, (k.anahtar == "onay" and deger > 0) and R.kizil or R.fildisiAcik)
     U.Etiket(k.ad, x + 22, y + 88, R.ust, 0, 10)
     U.BaklavaCizgi(x + w - 24, y + 26, 7, R.pirinc, 0.8)

     if ustunde then
          U.imlec = true
          if U.Tik(x, y, w, h) then B.Git(k.sayfa) end
     end
end

local function Ciz(x, y, w, h)
     local v = B.Veri.kumanda
     if not v then return U.Bekleniyor(x, y, w, h) end

     local ply = LocalPlayer()
     local gorev = B.Gorevde(ply)

     -- sayı kutuları
     local kw = (w - 5 * 16) / 6
     for i, k in ipairs(KUTULAR) do
          SayiKutusu(x + (i - 1) * (kw + 16), y + 8, kw, 110, k, v.sayilar[k.anahtar] or 0)
     end

     local solW = 790
     local sagX = x + solW + 24
     local sagW = w - solW - 24
     local govdeY = y + 142

     -- AÇIK OLAYLAR
     U.Bolum("Incidentes abiertos", x, govdeY + 10, solW, #v.olaylar > 0 and "página Incidentes para ver todos" or nil)
     local oy = govdeY + 30
     if #v.olaylar == 0 then
          U.Bos(x, oy, solW, 180, "Cola vacía", gorev and "Cuando llegue un nuevo aviso, aparecerá aquí." or "Entra de servicio para recibir avisos.")
     end
     for i, o in ipairs(v.olaylar) do
          local sy = oy + (i - 1) * 46
          local tik = U.Satir(x, sy, solW, 46)
          local renk = B.OncelikRenk[o.oncelik] or R.ada
          U.Baklava(x + 16, sy + 23, 6, renk, o.oncelik >= 4 and (0.5 + 0.5 * math.sin(U.Zaman() * 6)) or 1)
          U.Yazi(U.Kisalt(o.baslik, 14, 600, 420), 14, 600, x + 36, sy + 16, R.fildisi)
          U.Yazi(U.Kisalt(o.bolge, 11, 700, 420), 11, 700, x + 36, sy + 34, R.soluk)
          U.Rozet(B.OlayDurum[o.durum] or o.durum, x + solW - 110, sy + 23, B.DurumRenk[o.durum] or R.ada, false, 2)
          U.Yazi(B.Once(o.zaman), 11, 700, x + solW - 12, sy + 23, R.soluk, 2)
          if tik then B.Git("olay", {id = o.id}) end
     end

     -- SON KARARNAME
     local ky = govdeY + 326
     U.Bolum("Último decreto en vigor", x, ky + 10, solW)
     if v.kararname then
          local k = v.kararname
          U.Kart(x, ky + 30, solW, 150)
          U.Resim(B.Doku("muhur"), x + solW - 132, ky + 44, 110, 110, R.beyaz, 0.16)
          U.Etiket((B.KararnameTurAd and B.KararnameTurAd[k.tur] or "Decreto del Ministerio") .. " N.º " .. k.no, x + 22, ky + 54, R.ust)
          U.Yazi(U.Kisalt(k.baslik, 18, 600, solW - 180), 18, 600, x + 22, ky + 80, R.fildisiAcik)
          U.Paragraf(k.metin, 12, 700, x + 22, ky + 98, solW - 190, R.govde, 18, 3)
          U.Yazi("— " .. k.yazan_ad .. " · " .. B.Tarih(k.zaman), 11, 700, x + 22, ky + 164, R.soluk)
          if U.Icinde(x, ky + 30, solW, 150) then
               U.imlec = true
               if U.Tik(x, ky + 30, solW, 150) then B.Git("kararname") end
          end
     else
          U.Bos(x, ky + 30, solW, 150, "No hay decretos en vigor")
     end

     -- SAĞ: mesai özeti
     U.Kart(sagX, govdeY, sagW, 132, gorev)
     U.Etiket("Tu turno", sagX + 20, govdeY + 24, R.ust)
     if v.ben.denetci then
          U.Yazi("Vista de inspector", 17, 600, sagX + 20, govdeY + 54, R.mor)
          U.Paragraf("Como superadmin ves todas las páginas; no apareces en la plantilla.", 12, 700, sagX + 20, govdeY + 72, sagW - 40, R.ada, 18)
     else
          U.Yazi(gorev and "De servicio" or "Fuera de servicio", 17, 600, sagX + 20, govdeY + 54, gorev and R.yesil or R.ada)
          U.Yazi("Esta semana " .. B.SureUzun(v.ben.hafta or 0) .. "  ·  total " .. B.SureUzun(v.ben.mesai or 0), 12, 700, sagX + 20, govdeY + 80, R.govde)
          if gorev and B.Yetkili(ply, "olay") then
               if U.Dugme(sagX + sagW - 190, govdeY + 88, 170, 30, "Pedir refuerzos", "tehlike", false, "Envía tu ubicación como aviso urgente a todo el personal de servicio.") then
                    B.Onay("Llamada de refuerzos", "Tu ubicación llegará como aviso URGENTE a todo el personal de servicio. ¿Seguro?", "Llamar", function() B.Iste("takviye", {}) end, true)
               end
          end
     end

     -- tehdit seviyesi
     local ty = govdeY + 150
     U.Bolum("Nivel de amenaza", sagX, ty + 10, sagW)
     local seviye = GetGlobalInt("SBTehdit", 0)
     local yetkili = B.Yetkili(ply, "tehdit")
     local bw = (sagW - 16) / 3
     for i = 0, 2 do
          local t = B.Tehdit[i]
          local bx = sagX + i * (bw + 8)
          local secili = seviye == i
          local ustunde = yetkili and not secili and U.Icinde(bx, ty + 28, bw, 44)
          U.Kutu(bx, ty + 28, bw, 44, t.renk, secili and 0.22 or (ustunde and 0.1 or 0.04))
          U.Cerceve(bx, ty + 28, bw, 44, t.renk, secili and 1 or 0.4)
          U.Yazi(B.Buyuk(t.ad), 11, 600, bx + bw / 2, ty + 50, secili and t.renk or R.soluk, 1, 1.4)
          if ustunde then
               U.imlec = true
               U.ipucu = t.alt
               if U.Tik(bx, ty + 28, bw, 44) then
                    B.Onay("Nivel de amenaza", "Se declarará el nivel \"" .. t.ad .. "\" y se anunciará a todo el personal de servicio.", "Declarar", function() B.Iste("tehdit.ayarla", {seviye = i}) end, i == 2)
               end
          end
     end
     U.Yazi((B.Tehdit[seviye] or B.Tehdit[0]).alt, 12, 700, sagX, ty + 88, R.ada)

     -- mesaideki kadro
     local my = ty + 112
     U.Bolum("Personal de servicio", sagX, my + 10, sagW, #v.kadro .. " personas")
     local lh = y + h - (my + 30)
     if #v.kadro == 0 then
          U.Bos(sagX, my + 30, sagW, lh, "Nadie de servicio")
     else
          local kay = U.Kaydir("kumanda.kadro", sagX, my + 30, sagW, lh, #v.kadro * 38)
          for i, k in ipairs(v.kadro) do
               local sy = my + 30 + (i - 1) * 38 - kay
               if U.Gorunur(sy, 38) then
                    local tik = U.Satir(sagX, sy, sagW - 8, 38)
                    U.Baklava(sagX + 12, sy + 19, 4, R.yesil, 1)
                    U.Yazi(U.Kisalt(k.ad, 13, 600, 190), 13, 600, sagX + 26, sy + 19, R.fildisi)
                    U.Yazi(U.Kisalt(k.unvan, 11, 700, 170), 11, 700, sagX + 226, sy + 19, R.ada)
                    U.Yazi(B.DaireAd(k.daire, true), 10, 600, sagX + sagW - 18, sy + 19, R.soluk, 2, 1.2)
                    if tik then B.Git("personel", {id = k.id}) end
               end
          end
          U.KaydirBitir()
     end
end

B.KararnameTurAd = {genel = "Decreto del Ministerio", egitim = "Decreto educativo", guvenlik = "Decreto de seguridad"}

B.Sayfa("kumanda", {
     ad = "Mando", sira = 1, izin = "kumanda", kanallar = {kumanda = true},
     alt = function()
          local b = B.Bilgi(LocalPlayer())
          return b and (b.unvan .. " · " .. B.DaireAd(b.daire)) or ""
     end,
     ac = function() B.Sor("kumanda", {}) end,
     ciz = Ciz,
})
