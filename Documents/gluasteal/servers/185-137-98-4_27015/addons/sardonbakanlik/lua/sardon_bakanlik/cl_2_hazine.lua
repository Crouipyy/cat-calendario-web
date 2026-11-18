-- "addons\\sardonbakanlik\\lua\\sardon_bakanlik\\cl_2_hazine.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sicil Defteri :: Hazine. Bakiye, haftalık özet, hareketler. (Görmek 4. kademe, harcamak Bakan / Müsteşar)

local B = SardonBakanlik
local U = B.UI
local R = U.R

local TUR_AD = {
     ceza = "Multas", odul = "Recompensas por capturas", ikramiye = "Gratificaciones", tabu = "Hechizo Taboo", ruhemici = "Envíos de Dementores",
     onarim = "Pagos por reparación", bagis = "Ingresos depositados", yonetim = "Ajuste de gestión",
}

local function Ciz(x, y, w, h)
     local v = B.Veri["hazine.durum"]
     if not v then return U.Bekleniyor(x, y, w, h) end

     -- bakiye kartı
     U.Kart(x, y + 6, 470, 220, true)
     U.Resim(B.Doku("muhur"), x + 300, y + 30, 150, 150, R.beyaz, 0.12)
     U.Etiket("Saldo del Tesoro", x + 26, y + 36, R.ust)
     U.Yazi(B.Para(v.bakiye), 44, 600, x + 26, y + 92, v.bakiye >= 0 and R.fildisiAcik or R.kizil)
     U.Paragraf("Las multas y confiscaciones entran aquí; las recompensas por capturas, gratificaciones, Taboo y envíos de Dementores salen de aquí.", 12, 700, x + 26, y + 124, 420, R.ada, 18)
     if U.Dugme(x + 26, y + 176, 200, 32, "Ingresar en el Tesoro", "ikincil") then
          B.MetinSor("Ingresar en el Tesoro", "Cantidad que se transferirá del dinero que llevas al Tesoro.", "p. ej. 500", function(metin) B.Iste("hazine.yatir", {miktar = tonumber(metin) or 0}) end, {sayi = true, maks = 6, dugme = "Ingresar"})
     end

     -- haftalık özet
     U.Bolum("Últimos 7 días", x, y + 254, 470)
     local enBuyuk = 1
     for _, o in ipairs(v.ozet) do enBuyuk = math.max(enBuyuk, math.abs(o.toplam)) end
     for i, o in ipairs(v.ozet) do
          local sy = y + 274 + (i - 1) * 52
          if sy + 52 <= y + h then
               local gelir = o.toplam >= 0
               U.Yazi(TUR_AD[o.tur] or o.tur, 13, 600, x, sy + 14, R.fildisi)
               U.Yazi((gelir and "+" or "") .. B.Para(o.toplam), 13, 600, x + 470, sy + 14, gelir and R.yesil or R.kizil, 2)
               U.Cubuk(x, sy + 32, 470, 5, math.abs(o.toplam) / enBuyuk, gelir and R.yesil or R.kizil)
               U.Yazi(o.n .. " movimientos", 10, 700, x, sy + 46, R.soluk)
          end
     end
     if #v.ozet == 0 then U.Yazi("Sin movimientos esta semana.", 12, 700, x, y + 290, R.soluk) end

     -- hareketler
     local sx, sw = x + 500, w - 500
     U.Bolum("Movimientos", sx, y + 16, sw)
     local ly, lh = y + 36, h - 36
     if #v.hareketler == 0 then return U.Bos(sx, ly, sw, lh, "No hay movimientos en el libro") end
     local kay = U.Kaydir("hazine.hareket", sx, ly, sw, lh, #v.hareketler * 46)
     for i, r in ipairs(v.hareketler) do
          local sy = ly + (i - 1) * 46 - kay
          if U.Gorunur(sy, 46) then
               local gelir = r.miktar >= 0
               U.Kutu(sx, sy + 45, sw - 10, 1, R.cizgi, 0.22)
               U.Baklava(sx + 10, sy + 23, 4, gelir and R.yesil or R.kizil, 1)
               U.Yazi(U.Kisalt(r.aciklama, 13, 600, sw - 300), 13, 600, sx + 26, sy + 16, R.fildisi)
               U.Yazi((TUR_AD[r.tur] or r.tur) .. (r.kisi_ad ~= "" and (" · " .. r.kisi_ad) or "") .. " · " .. B.Tarih(r.zaman), 11, 700, sx + 26, sy + 34, R.soluk)
               U.Yazi((gelir and "+" or "") .. B.Para(r.miktar), 15, 600, sx + sw - 24, sy + 23, gelir and R.yesil or R.kizil, 2)
          end
     end
     U.KaydirBitir()
end

B.Sayfa("hazine", {
     ad = "Tesoro", sira = 12, izin = "hazine", kanallar = {["hazine.durum"] = true},
     alt = "La caja del Ministerio.",
     ac = function() B.Sor("hazine.durum", {}) end,
     ciz = Ciz,
})