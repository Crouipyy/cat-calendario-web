-- "addons\\sardonyaratik\\lua\\sardon_yaratik\\cl_8defter_diger.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- [sardon] yaratik :: Yaratık Defteri › VİVARYUM ve ANSİKLOPEDİ

local Y = SardonYaratik
local A = Y.Ayar
local D = Y.D
local R = Y.R

------------------------------------------------------------------------ vivaryum

Y.DefterCiz.vivaryum = function(pnl, T, w, h)
     local HX, HY, HW, HH = 40, 104, 980, 756
     T.Kutu(HX, HY, HW, HH)

     local acik = Y.Benim and Y.Benim.vivaryum
     if not Y.AlanVar() then
          T.Yazi("Aún no se ha definido el área del vivario.", 20, "kitap", HX + HW / 2, HY + HH / 2 - 14, R.sonuk, 1)
          T.Yazi("Los staff lo marcan con dos esquinas en Shine Admin › Criaturas.", 13, 400, HX + HW / 2, HY + HH / 2 + 18, R.kilit, 1)
     elseif not acik then
          -- 2026-11-10: kişisel vivaryum SYB › Vivaryum Anahtarı ister
          T.Ton(R.kilit, 0.8)
          T.Baklava(HX + HW / 2, HY + HH / 2 - 92, 9)
          T.Yazi("Aún no tienes un vivario", 22, "kitap", HX + HW / 2, HY + HH / 2 - 52, R.soluk, 1)
          local satir = T.Sar("Cuando desbloqueas la Llave del Vivario en Desarrollo › árbol SYB, tu Bolsa de captura abre tu vivario: dejas la bolsa en el suelo, entras, tus criaturas viven ahí e incubas huevos.", 14, "kitap", HW - 200)
          for i, l in ipairs(satir) do
               T.Yazi(l, 14, "kitap", HX + HW / 2, HY + HH / 2 - 12 + (i - 1) * 22, R.yazi, 1)
          end
          T.Yazi("Sin vivario, las criaturas que llevas te acompañan; las que envías de vuelta esperan (no puedes llenar el comedero).", 12, 400,
               HX + HW / 2, HY + HH / 2 + 22 + #satir * 22, R.sonuk, 1)
     else
          local a, b = Y.Alan.min, Y.Alan.max
          local gx, gy = b.x - a.x, b.y - a.y
          local olc = math.min((HW - 80) / gx, (HH - 140) / gy)
          local ox = HX + HW / 2 - gx * olc / 2
          local oy = HY + (HH - 60) / 2 - gy * olc / 2
          local function Harita(p) return ox + (p.x - a.x) * olc, oy + (b.y - p.y) * olc end

          T.Ton(Color(16, 34, 24), 1)
          T.Dolu(ox, oy, gx * olc, gy * olc)
          T.Ton(Color(26, 46, 33), 1)
          for i = 1, 7 do
               T.Dolu(ox + gx * olc * i / 8, oy, 1, gy * olc)
               T.Dolu(ox, oy + gy * olc * i / 8, gx * olc, 1)
          end
          T.Ton(R.altin, 0.9)
          T.Cerceve(ox, oy, gx * olc, gy * olc)

          for i, p in ipairs(Y.Alan.yemlik or {}) do
               local x, y = Harita(p)
               T.Ton(R.aclik, 1)
               T.Baklava(x, y, 7)
               T.Yazi("Comedero", 10, 600, x, y + 16, R.aclik, 1)
          end
          for i, p in ipairs(Y.Alan.yuva or {}) do
               local x, y = Harita(p)
               T.Ton(R.uyari, 1)
               T.Dolu(x - 6, y - 6, 12, 12)
               T.Yazi("Nido", 10, 600, x, y + 16, R.uyari, 1)
          end
          -- kayalık (gizlenen evin yeri) ve çıkış sütunu
          if Y.EvIzi then
               -- ayak izi kuzey duvarını aşıyor: alanın içine kırpılır
               local mn = Vector(math.max(Y.EvIzi.min.x, a.x), math.max(Y.EvIzi.min.y, a.y), 0)
               local mx = Vector(math.min(Y.EvIzi.max.x, b.x), math.min(Y.EvIzi.max.y, b.y), 0)
               local x1, y1 = Harita(mn)
               local x2, y2 = Harita(mx)
               T.Ton(Color(60, 66, 58), 0.9)
               T.Dolu(math.min(x1, x2), math.min(y1, y2), math.abs(x2 - x1), math.abs(y2 - y1))
               T.Yazi("Risco", 10, 600, (x1 + x2) / 2, (y1 + y2) / 2, R.sonuk, 1)
          end
          local cik = istable(Y.Alan.cikis) and Y.Alan.cikis[1]
          if isvector(cik) then
               local x, y = Harita(cik)
               T.Isik(x, y, 16, R.altin, 90)
               T.Ton(R.altin, 1)
               T.Baklava(x, y, 6)
               T.Yazi("Salida", 10, 600, x, y + 16, R.altin, 1)
          end

          local ben = LocalPlayer()
          for _, ent in ipairs(Y.YaratikListe and Y.YaratikListe() or ents.FindByClass("sardon_yaratik")) do
               if IsValid(ent) and ent.CizimKonumu then
                    local p = ent:CizimKonumu()
                    if Y.AlanIcinde(p, 64) then
                         local x, y = Harita(p)
                         local benim = ent:GetSahip() == ben
                         if benim then
                              T.Isik(x, y, 14, R.altin, 60)
                              T.Ton(ent:GetEvre() == 0 and R.uyari or R.parlak, 1)
                              T.Baklava(x, y, 5)
                              local tur = ent:TurVeri()
                              T.Yazi(ent:GetEvre() == 0 and "huevo" or (ent:GetAd() ~= "" and ent:GetAd() or (tur and tur.ad or "")), 10, 600, x + 8, y - 8, R.soluk, 0)
                         else
                              T.Ton(R.kilit, 1)
                              T.Dolu(x - 2, y - 2, 4, 4)
                         end
                    end
               end
          end

          local p = ben:GetPos()
          if Y.AlanIcinde(p, 256) then
               local x, y = Harita(p)
               local yaw = math.rad(ben:EyeAngles().y)
               local function N(aci, r) return {x = T.X(x + math.cos(yaw + aci) * r), y = T.Y(y - math.sin(yaw + aci) * r)} end
               draw.NoTexture()
               surface.SetDrawColor(R.tamam)
               surface.DrawPoly({N(0, 12), N(-2.5, 8), N(2.5, 8)})
               T.Yazi("tú", 10, 600, x, y + 16, R.tamam, 1)
          end
          T.Yazi(string.format("Área %d × %d u  (~%d × %d m)", gx, gy, gx * 0.019, gy * 0.019), 11, 400, HX + HW - 18, HY + 22, R.sonuk, 2)

          -- sahibin yönetimi: yemlik / yuva taşıma (kendi vivaryumundayken), çanta kilidi
          local icerde = Y.KendiDunyasinda(LocalPlayer())
          local bw, bh = 220, 40
          local by = HY + HH - 58
          local bx = HX + (HW - (bw * 3 + 24)) / 2
          pnl:Dugme(bx, by, bw, bh, "Mover comedero", function() Y.VivYerlestirBasla("yemlik") end, icerde)
          pnl:Dugme(bx + bw + 12, by, bw, bh, "Mover nido", function() Y.VivYerlestirBasla("yuva") end, icerde)
          local kilit = Y.Benim and Y.Benim.kilit
          pnl:Dugme(bx + (bw + 12) * 2, by, bw, bh, kilit and "Bolsa: cerrada" or "Bolsa: visitas abiertas", function() Y.Islem("viv_kilit") end, true, kilit)
          if not icerde then
               T.Yazi("Para mover objetos, entra en tu vivario (Bolsa de captura › Entrar al vivario).", 11, 400, HX + HW / 2, by - 14, R.sonuk, 1)
          end
     end

     -- yemlik stoğu
     local SX, SW = 1040, 520
     T.Kutu(SX, HY, SW, 452)
     T.Yazi("STOCK DEL COMEDERO", 12, "baslik", SX + 18, HY + 18, R.altin, 0, 3)
     local stok = (Y.Benim and Y.Benim.yemlik) or {}
     local y = HY + 58
     for _, yem in ipairs(Y.YemSirasi) do
          local yv = Y.Yemler[yem]
          local n = stok[yem] or 0
          T.Yazi(yv.ad, 14, "isim", SX + 20, y, R.parlak, 0)
          T.Yazi(n .. "/" .. A.YemlikSiniri, 12, 600, SX + SW - 20, y, n > 0 and R.soluk or R.kilit, 2)
          T.Cubuk(SX + 20, y + 14, SW - 40, 5, n / A.YemlikSiniri, R.aclik)
          local sevenler = {}
          for _, id in ipairs(Y.TurSirasi) do
               if Y.YemUygunluk(Y.Turler[id], yem) >= 1 then sevenler[#sevenler + 1] = Y.Turler[id].ad end
          end
          T.Yazi(yv.genel and "media eficacia para todas las especies" or ("les gusta: " .. table.concat(sevenler, ", ")), 10, 400, SX + 20, y + 32, R.sonuk, 0)
          y = y + 74
     end

     T.Kutu(SX, HY + 470, SW, 286)
     T.Yazi("CÓMO FUNCIONA", 12, "baslik", SX + 18, HY + 488, R.altin, 0, 3)
     local metin = {
          "Entras a tu vivario con la Bolsa de captura (inventario › Entrar al vivario); sales por la boca de la bolsa en el jardín.",
          "El vivario es solo tuyo: tus criaturas aparecen cuando estás dentro. Si abres visitas, otros pueden pedir permiso.",
          "Si tienes hambre estando fuera, comen del comedero lo que les gusta. Añade comida desde el inventario con «Poner en comedero».",
          "Si una necesidad se queda a cero, acorta la vida de la criatura. La comida equivocada le sienta mal.",
          "Los jóvenes y adultos felices (+70 %) acumulan producto en la bolsa.",
     }
     local yy = HY + 520
     for _, m in ipairs(metin) do
          -- Playfair rakamları küçük harf boyunda: sayılı satırlar Montserrat
          local satir = T.Sar(m, 12, 400, SW - 52)
          T.Ton(R.altin, 0.8)
          T.Baklava(SX + 24, yy, 3)
          for i, s in ipairs(satir) do
               T.Yazi(s, 12, 400, SX + 36, yy + (i - 1) * 18, R.yazi, 0)
          end
          yy = yy + #satir * 18 + 10
     end
end

------------------------------------------------------------------------ ansiklopedi

local function Sende(id)
     local n = 0
     for _, k in ipairs((Y.Benim and Y.Benim.liste) or {}) do
          if k.tur == id and k.durum ~= D.OLU then n = n + 1 end
     end
     return n
end

Y.DefterCiz.ansiklopedi = function(pnl, T, w, h)
     local LX, LY, LW, LH = 40, 104, 372, 756
     pnl.ansSecili = pnl.ansSecili or Y.TurSirasi[1]
     T.Kutu(LX, LY, LW, LH)
     local satirH = (LH - 20) / #Y.TurSirasi
     for i, id in ipairs(Y.TurSirasi) do
          local tur = Y.Turler[id]
          local y = LY + 10 + (i - 1) * satirH
          local secili = pnl.ansSecili == id
          local ustunde = pnl:Ustunde(LX + 10, y, LW - 20, satirH - 4)
          T.Ton(secili and R.satirSecili or (ustunde and Color(22, 38, 29) or R.satir), 1)
          T.Dolu(LX + 10, y, LW - 20, satirH - 4)
          T.Yazi(Y.SinifKod(tur.sinif), 10, 600, LX + 26, y + (satirH - 4) / 2, tur.sinif >= 4 and R.hata or (tur.sinif == 3 and R.uyari or R.tamam), 0, 1)
          T.Yazi(tur.ad, 15, "isim", LX + 92, y + (satirH - 4) / 2, secili and R.parlak or R.soluk, 0)
          local n = Sende(id)
          if n > 0 then T.Yazi("tienes " .. n, 10, 600, LX + LW - 26, y + (satirH - 4) / 2, R.altin, 2) end
          pnl:Tik(LX + 10, y, LW - 20, satirH - 4, function()
               pnl.ansSecili = id
               pnl.ansRenk = nil
          end)
     end

     local id = pnl.ansSecili
     local tur = Y.Turler[id]
     if not tur then return end

     -- model ve renkler
     pnl.model2 = pnl.model2 or Y.ModelGoster()
     local ri = pnl.ansRenk or 1
     local renk = tur.renkler[ri] or tur.renkler[1]
     pnl.model2:Ayarla(tur, renk and renk.bg or 0, 3, false)
     T.Isik(742, 500, 230, R.altin, 18)
     if pnl.model2.eksik then
          T.Yazi("El modelo no está en este PC.", 13, 400, 742, 320, R.hata, 1)
     else
          local ex, ey = pnl:LocalToScreen(T.X(432), T.Y(100))
          pnl.model2:Ciz(ex, ey, 620 * T.S, 440 * T.S, false)
     end
     T.Yazi(tur.ad, 30, "isim", 742, 562, R.parlak, 1)
     T.Yazi(Y.SinifKod(tur.sinif) .. "  ·  " .. Y.Siniflar[tur.sinif].ad, 13, 600, 742, 596, R.sonuk, 1)

     -- renk örnekleri
     local n = #tur.renkler
     local rw = 96
     local rx = 742 - (n * rw + (n - 1) * 8) / 2
     T.Yazi("COLORES", 11, "baslik", 742, 640, R.sonuk, 1, 3)
     for i, r in ipairs(tur.renkler) do
          local x = rx + (i - 1) * (rw + 8)
          local secili = i == ri
          local ozel = (tur.disi == i and "hembra") or nil
          for _, e in ipairs(tur.efsanevi or {}) do if e == i then ozel = "legendario" end end
          T.Ton(secili and R.satirSecili or R.satir, 1)
          T.Dolu(x, 656, rw, 46)
          T.Ton(ozel == "legendario" and Y.Nadirlik[3].renk or (secili and R.altin or R.cizgi), 1)
          T.Cerceve(x, 656, rw, 46)
          T.Yazi(r.ad, 11, 600, x + rw / 2, 672, secili and R.parlak or R.soluk, 1)
          if ozel then T.Yazi(ozel, 9, 600, x + rw / 2, 690, ozel == "legendario" and Y.Nadirlik[3].renk or R.sevgi, 1) end
          pnl:Tik(x, 656, rw, 46, function() pnl.ansRenk = i end)
     end
     local nadirYazi = "La rareza se fija al incubar: " .. Y.Nadirlik[1].ad .. " · " .. Y.Nadirlik[2].ad .. " (producto ×1.5) · " .. Y.Nadirlik[3].ad .. " (producto ×2)"
     T.Yazi(nadirYazi, 11, 400, 742, 726, R.sonuk, 1)

     -- animasyon önizleme: modeldeki her animasyon bir düğme
     if pnl.ansAnimTur ~= id then
          pnl.ansAnimTur = id
          pnl.ansAnim = "idle"
     end
     pnl.model2:Anim(pnl.ansAnim or "idle")
     local animler = pnl.model2:Animler()
     if #animler > 0 then
          T.Yazi("ANIMACIONES", 11, "baslik", 742, 752, R.sonuk, 1, 3)
          local sutun = math.ceil(#animler / 2)
          local aw, ah, ara = 92, 26, 6
          for i, a in ipairs(animler) do
               local sira = i <= sutun and 0 or 1
               local j = sira == 0 and i or (i - sutun)
               local adet = sira == 0 and sutun or (#animler - sutun)
               local x = 742 - (adet * aw + (adet - 1) * ara) / 2 + (j - 1) * (aw + ara)
               local y = 768 + sira * (ah + 6)
               local secili = pnl.ansAnim == a[1]
               local ustunde = pnl:Ustunde(x, y, aw, ah)
               T.Ton(secili and R.satirSecili or (ustunde and Color(22, 38, 29) or R.satir), 1)
               T.Dolu(x, y, aw, ah)
               T.Ton(secili and R.altin or R.cizgi, 1)
               T.Cerceve(x, y, aw, ah)
               T.Yazi(a[2], 11, 600, x + aw / 2, y + ah / 2, secili and R.parlak or R.soluk, 1)
               pnl:Tik(x, y, aw, ah, function() pnl.ansAnim = a[1] end)
          end
     end

     -- bilgi
     local RX, RW = 1072, 488
     T.Kutu(RX, 104, RW, 756)
     local y = 132
     local satir = T.Sar(tur.aciklama or "", 15, "kitap", RW - 40)
     for i, s in ipairs(satir) do T.Yazi(s, 15, "kitap", RX + 20, y + (i - 1) * 24, R.yazi, 0) end
     y = y + #satir * 24 + 18
     T.Ton(R.cizgi, 1)
     T.Dolu(RX + 20, y, RW - 40, 1)
     y = y + 22

     local function Bilgi(ad, deger)
          T.Yazi(Y.Buyuk(ad), 10, "baslik", RX + 20, y, R.altin, 0, 2)
          local s2 = T.Sar(deger, 13, 400, RW - 190)
          for i, s in ipairs(s2) do T.Yazi(s, 13, 400, RX + 170, y + (i - 1) * 19, R.soluk, 0) end
          y = y + math.max(1, #s2) * 19 + 10
     end
     local roller = {}
     if tur.rol.takip then roller[#roller + 1] = "camina a tu lado" end
     if tur.rol.omuz then roller[#roller + 1] = "se lleva al hombro" end
     if tur.rol.binek then roller[#roller + 1] = "montura" end
     Bilgi("Vida", table.concat(roller, ", ") .. (tur.rol.yuru and "" or "; no camina"))
     Bilgi("Alimento", Y.BesinYazi(tur))
     Bilgi("Necesidades", string.format("Hambre %d h · suciedad %d h · atención %d h", tur.ihtiyac.aclik, tur.ihtiyac.temizlik, tur.ihtiyac.sevgi))
     local u = tur.urun
     Bilgi("Producto", u and (u.galleon and ("Galeones (" .. u.galleon[1] .. "-" .. u.galleon[2] .. ")") or u.ad) .. " · cada " .. (u and u.aralik or 0) .. " h" or "—")
     if tur.olumUrun then Bilgi("Al morir", tur.olumUrun.ad) end
     Bilgi("Incubación", tur.kulucka .. " min")
     local izin, neden = true, nil
     local char = LocalPlayer():GetCharacter()
     if char then izin, neden = Y.SinifIzni(char, tur.sinif) end
     Bilgi("Obtención", (tur.fiyat and ("Huevo en Cuidador de criaturas por " .. tur.fiyat .. " galeones") or "No se vende en tienda") .. (izin and "" or (" · " .. neden)))
     y = y + 6
     for _, oz in ipairs(tur.ozellikler or {}) do
          T.Ton(R.altin, 0.8)
          T.Baklava(RX + 26, y, 3)
          local s2 = T.Sar(oz, 12, "kitap", RW - 70)
          for i, s in ipairs(s2) do T.Yazi(s, 12, "kitap", RX + 40, y + (i - 1) * 18, R.yazi, 0) end
          y = y + #s2 * 18 + 6
     end
end
