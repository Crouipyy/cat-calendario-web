-- "addons\\sardonakran\\lua\\sardon_akran\\_sh_runler.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Akran Yardımı :: büyü rünleri (asa hareketi şablonları)
-- Her şablon [-1, 1] karesinde tek vuruşluk bir yoldur (y yukarı). Çizim yönü ve başlangıç
-- noktası önemlidir; talimde parlayan halka başlangıcı, akan kıvılcım yönü gösterir.
-- Listede olmayan bir Temel büyü için addan türetilen bir rün üretilir (her zaman aynı çıkar).

local SA = SardonAkran

local pi = math.pi

local function Yay(cx, cy, rx, ry, a0, a1, n)
     n = n or 24
     local out = {}
     for i = 0, n do
          local a = math.rad(a0 + (a1 - a0) * i / n)
          out[#out + 1] = {x = cx + math.cos(a) * rx, y = cy + math.sin(a) * ry}
     end
     return out
end

local function Bezier(x0, y0, cx, cy, x1, y1, n)
     n = n or 16
     local out = {}
     for i = 0, n do
          local t = i / n
          local u = 1 - t
          out[#out + 1] = {x = u * u * x0 + 2 * u * t * cx + t * t * x1, y = u * u * y0 + 2 * u * t * cy + t * t * y1}
     end
     return out
end

local function Cizgi(...)
     local out = {}
     for _, p in ipairs({...}) do out[#out + 1] = {x = p[1], y = p[2]} end
     return out
end

local function Param(n, fn)
     local out = {}
     for i = 0, n do
          local x, y = fn(i / n)
          out[#out + 1] = {x = x, y = y}
     end
     return out
end

-- parçaları uç uca ekler (birleşim noktası tekrarlanmaz)
local function Birlestir(...)
     local out = {}
     for _, parca in ipairs({...}) do
          for i, p in ipairs(parca) do
               local son = out[#out]
               if (!(i == 1 and son and math.abs(son.x - p.x) < 1e-4 and math.abs(son.y - p.y) < 1e-4)) then
                    out[#out + 1] = p
               end
          end
     end
     return out
end

-- yolu verilen kutuya sığdırır (oranı korur)
local function Sigdir(pts, w, h)
     local minx, miny, maxx, maxy = math.huge, math.huge, -math.huge, -math.huge
     for _, p in ipairs(pts) do
          minx, maxx = math.min(minx, p.x), math.max(maxx, p.x)
          miny, maxy = math.min(miny, p.y), math.max(maxy, p.y)
     end
     local s = math.min(w * 2 / math.max(1e-6, maxx - minx), h * 2 / math.max(1e-6, maxy - miny))
     local cx, cy = (minx + maxx) / 2, (miny + maxy) / 2
     for _, p in ipairs(pts) do
          p.x, p.y = (p.x - cx) * s, (p.y - cy) * s
     end
     return pts
end

SA.Runler = {
     ["Accio"] = {
          tarif = "Sağ yandan başla, yukarıdan sola doğru geniş bir yay çiz; aşağıda sağa kıvrıl ve son anda kancayı kendine doğru yukarı çek.",
          yap = function()
               return Birlestir(Yay(0.05, 0.1, 0.8, 0.75, 20, 250), Cizgi({-0.22, -0.6}, {0.45, -0.8}, {0.25, -0.25}))
          end
     },
     ["Aguamenti"] = {
          tarif = "Soldan sağa iki tam dalga çiz: önce yukarı, sonra aşağı, suyun akışı gibi.",
          yap = function()
               return Param(48, function(t) return -0.95 + 1.9 * t, 0.4 * math.sin(2 * pi * 2 * t) end)
          end
     },
     ["Alohomora"] = {
          tarif = "Önce anahtarın halkasını çiz: alttan başla, saat yönünün tersine dön. Sonra dümdüz aşağı in ve dişi sağa doğru kıvır.",
          yap = function()
               return Birlestir(Yay(0, 0.45, 0.38, 0.38, -90, 270, 28), Cizgi({0, 0.07}, {0, -0.9}, {0.32, -0.9}, {0.32, -0.62}))
          end
     },
     ["Avis Sard"] = {
          tarif = "İki kanat çırpışı: soldan başlayıp yukarı doğru iki yay çiz, ortada aşağı dokun.",
          yap = function()
               return Birlestir(Yay(-0.5, -0.25, 0.5, 0.7, 180, 0, 18), Yay(0.5, -0.25, 0.5, 0.7, 180, 0, 18))
          end
     },
     ["Babbling Curse"] = {
          tarif = "Soldan sağa üç küçük ilmek at, dilin dolanması gibi.",
          yap = function()
               return Sigdir(Param(72, function(t)
                    local th = t * 6 * pi
                    return th - 2 * math.sin(th), -2 * math.cos(th)
               end), 0.95, 0.4)
          end
     },
     ["Colovaria"] = {
          tarif = "Merkezden başla ve saat yönünün tersine dönerek iki tur genişleyen bir sarmal çiz.",
          yap = function()
               return Param(64, function(t)
                    local r, a = 0.08 + 0.85 * t, 2 * 2 * pi * t
                    return math.cos(a) * r, math.sin(a) * r
               end)
          end
     },
     ["Confundo"] = {
          tarif = "Ortadan başla, yan yatmış bir sekiz (sonsuzluk işareti) çiz ve yine ortada bitir.",
          yap = function()
               return Sigdir(Param(64, function(t)
                    local a = pi / 2 + 2 * pi * t
                    local d = 1 + math.sin(a) ^ 2
                    return math.cos(a) / d, math.sin(a) * math.cos(a) / d
               end), 0.95, 0.4)
          end
     },
     ["Detoxify"] = {
          tarif = "Kısa bir iniş, ardından uzun ve keskin bir yükseliş: onay işareti gibi.",
          yap = function()
               return Cizgi({-0.75, 0.1}, {-0.25, -0.55}, {0.8, 0.8})
          end
     },
     ["Episkey"] = {
          tarif = "Kalbin alt ucundan başla, sola doğru kalbin yarısını çiz; tepede ortaya dokun ve sağ yarıyla alt uca dön.",
          yap = function()
               return Sigdir(Param(64, function(t)
                    local a = pi + 2 * pi * t
                    return 16 * math.sin(a) ^ 3, 13 * math.cos(a) - 5 * math.cos(2 * a) - 2 * math.cos(3 * a) - math.cos(4 * a)
               end), 0.85, 0.85)
          end
     },
     ["Extinguishing Spell"] = {
          tarif = "En dıştan, tepeden başla; saat yönünde içe doğru daralan bir sarmal çiz ve alevi merkezde boğ.",
          yap = function()
               return Param(64, function(t)
                    local r, a = 0.9 - 0.8 * t, pi / 2 - 1.75 * 2 * pi * t
                    return math.cos(a) * r, math.sin(a) * r
               end)
          end
     },
     ["Fallaciae"] = {
          tarif = "Sağ üstten başlayan bir S çiz: yukarıda sola kıvrıl, aşağıda sağa dönüp sola bitir.",
          yap = function()
               return Birlestir(Yay(0, 0.42, 0.45, 0.45, 30, 270, 20), Yay(0, -0.48, 0.45, 0.45, 90, -150, 20))
          end
     },
     ["Ferula"] = {
          tarif = "Yukarıdan aşağı, sargı sarar gibi altı kısa zikzak çiz.",
          yap = function()
               return Cizgi({-0.5, 0.9}, {0.5, 0.6}, {-0.5, 0.3}, {0.5, 0}, {-0.5, -0.3}, {0.5, -0.6}, {-0.5, -0.9})
          end
     },
     ["Finite"] = {
          tarif = "Sağa düz bir çizgi, çapraz aşağı, yine sağa: keskin bir Z.",
          yap = function()
               return Cizgi({-0.75, 0.6}, {0.75, 0.6}, {-0.75, -0.6}, {0.75, -0.6})
          end
     },
     ["Flipendo"] = {
          tarif = "Soldan başlayıp yukarıdan geniş bir kemer çiz; sağda bileğini aşağı doğru sertçe it.",
          yap = function()
               return Birlestir(Yay(0, -0.2, 0.8, 0.8, 180, 0, 24), Cizgi({0.8, -0.2}, {0.55, -0.85}))
          end
     },
     ["Fumos"] = {
          tarif = "Aşağıdan yukarı, yükseldikçe genişleyen kıvrımlarla bir duman sütunu çiz.",
          yap = function()
               return Param(56, function(t) return (0.1 + 0.35 * t) * math.sin(2 * pi * 2.5 * t), -0.95 + 1.9 * t end)
          end
     },
     ["Muffliato"] = {
          tarif = "Tepeden başla, saat yönünde tek ve kusursuz bir halka çiz.",
          yap = function()
               return Yay(0, 0, 0.85, 0.85, 90, -270, 40)
          end
     },
     ["Protego"] = {
          tarif = "Kalkanın üst kenarını soldan sağa çiz, sağ kenardan sivri uca kıvrılarak in, sol kenardan yukarı çıkıp başladığın yerde kapat.",
          yap = function()
               return Birlestir(Cizgi({-0.7, 0.8}, {0.7, 0.8}, {0.7, 0.15}), Bezier(0.7, 0.15, 0.65, -0.5, 0, -0.9), Bezier(0, -0.9, -0.65, -0.5, -0.7, 0.15), Cizgi({-0.7, 0.15}, {-0.7, 0.8}))
          end
     },
     ["Rictusempra"] = {
          tarif = "Soldan sağa sık ve küçük tırtıklar: kahkaha gibi titrek bir çizgi.",
          yap = function()
               local out = {}
               for i = 0, 10 do out[#out + 1] = {x = -0.95 + 1.9 * i / 10, y = (i % 2 == 0) and -0.2 or 0.2} end
               return out
          end
     },
     ["Tarantallegra"] = {
          tarif = "Yukarıdan aşağı üç ilmek: dans eden adımlar gibi döne döne in.",
          yap = function()
               return Sigdir(Param(72, function(t)
                    local th = t * 6 * pi
                    return 2 * math.cos(th), -(th - 2 * math.sin(th))
               end), 0.4, 0.95)
          end
     },
     ["Watterbalo"] = {
          tarif = "Damlanın sivri tepesinden başla, sola doğru yuvarlak bir su damlası çiz ve tepede kapat.",
          yap = function()
               return Sigdir(Param(56, function(t)
                    local a = pi / 2 + 2 * pi * t
                    return 0.55 * math.cos(a) * (1 - math.sin(a)), 0.9 * math.sin(a)
               end), 0.7, 0.9)
          end
     },
     ["Wingardium Leviosa"] = {
          tarif = "Savur ve fiske: soldan aşağı doğru yumuşak bir kavisle yukarı savrul, tepede bileğini aşağı sertçe indir.",
          yap = function()
               return Birlestir(Bezier(-0.95, 0.45, -0.3, -0.9, 0.45, 0.75, 22), Cizgi({0.45, 0.75}, {0.75, -0.55}))
          end
     }
}

-- addan türetilen yedek rün (Catmull-Rom ile yumuşatılmış 5 nokta)
local function Turet(buyu)
     local rnd = SA.Rastgele(tonumber(util.CRC(buyu)) or 7)
     local k = {}
     for i = 1, 5 do
          k[i] = {x = -0.85 + rnd() * 1.7, y = -0.85 + rnd() * 1.7}
     end

     local out = {}
     for i = 1, #k - 1 do
          local p0, p1, p2, p3 = k[math.max(1, i - 1)], k[i], k[i + 1], k[math.min(#k, i + 2)]
          for s = 0, 11 do
               local t = s / 12
               local t2, t3 = t * t, t * t * t
               out[#out + 1] = {
                    x = 0.5 * ((2 * p1.x) + (-p0.x + p2.x) * t + (2 * p0.x - 5 * p1.x + 4 * p2.x - p3.x) * t2 + (-p0.x + 3 * p1.x - 3 * p2.x + p3.x) * t3),
                    y = 0.5 * ((2 * p1.y) + (-p0.y + p2.y) * t + (2 * p0.y - 5 * p1.y + 4 * p2.y - p3.y) * t2 + (-p0.y + 3 * p1.y - 3 * p2.y + p3.y) * t3)
               }
          end
     end
     out[#out + 1] = {x = k[#k].x, y = k[#k].y}
     return Sigdir(out, 0.9, 0.9)
end

-- segmentleri en fazla adim uzunluğunda olacak şekilde sıklaştırır (hayalet rün ve yakınlık için)
local function Siklastir(pts, adim)
     local out = {}
     for i = 1, #pts - 1 do
          local a, b = pts[i], pts[i + 1]
          local d = math.sqrt((b.x - a.x) ^ 2 + (b.y - a.y) ^ 2)
          local n = math.max(1, math.ceil(d / adim))
          for s = 0, n - 1 do
               out[#out + 1] = {x = a.x + (b.x - a.x) * s / n, y = a.y + (b.y - a.y) * s / n}
          end
     end
     out[#out + 1] = {x = pts[#pts].x, y = pts[#pts].y}
     return out
end

local onbellek = {}

-- {ham = [-1,1] yoğun yol, norm = tanıma için normalleştirilmiş, uzunluk, tarif, uretildi}
function SA.Sablon(buyu)
     if (!isstring(buyu)) then return nil end
     local s = onbellek[buyu]
     if (s) then return s end

     local tanim = SA.Runler[buyu]
     local ham = tanim and tanim.yap() or Turet(buyu)
     ham = Siklastir(ham, 0.04)

     local norm = SA.Normallestir(SA.Yeniden(ham, SA.ORNEK))
     s = {
          ham = ham,
          norm = norm,
          uzunluk = norm and SA.Uzunluk(norm) or 1,
          tarif = tanim and tanim.tarif or "Kitaptaki çizimi izle: parlayan halkadan başla, kıvılcımın yönünde tek hareketle bitir.",
          uretildi = tanim == nil
     }
     onbellek[buyu] = s
     return s
end
